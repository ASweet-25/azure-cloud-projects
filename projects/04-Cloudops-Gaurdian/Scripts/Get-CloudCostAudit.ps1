# CloudOps Guardian - Cost and Configuration Audit
# Purpose: Identify potential unnecessary Azure expenses.
# This script is read-only.
$ErrorActionPreference = "Stop"
$rg = "RG-WINDOWS-LAB"

# Confirm Azure authentication.
if (-not (Get-AzContext)) {
    throw "Connect to Azure using Connect-AzAccount."
}

# Retrieve infrastructure information.
$vms = @(Get-AzVM -ResourceGroupName $rg -Status)
$disks = @(Get-AzDisk -ResourceGroupName $rg)
$pips = @(Get-AzPublicIpAddress -ResourceGroupName $rg)
$storage = @(Get-AzStorageAccount -ResourceGroupName $rg)

# Audit virtual machine power states.
Write-Host "`n=== COMPUTE AUDIT ===" -ForegroundColor Cyan
$vms |
    Select-Object Name, PowerState,
        @{Name="Size";Expression={$_.HardwareProfile.VmSize}} |
    Format-Table -AutoSize

# Identify disks that are not attached to a VM.
Write-Host "`n=== DISK AUDIT ===" -ForegroundColor Cyan
$unusedDisks = @($disks | Where-Object {
    $_.DiskState -eq "Unattached"
})
if ($unusedDisks.Count -gt 0) {
    Write-Warning "Unattached disks require investigation."
    $unusedDisks | Select-Object Name, DiskSizeGB, DiskState
}
else {
    Write-Host "No unattached disks found." -ForegroundColor Green
}

# Identify public IPs without an IP configuration or NAT gateway.
Write-Host "`n=== PUBLIC IP AUDIT ===" -ForegroundColor Cyan
$unusedPips = @($pips | Where-Object {
    -not $_.IpConfiguration -and -not $_.NatGateway
})
if ($unusedPips.Count -gt 0) {
    Write-Warning "Unassociated public IPs require investigation."
    $unusedPips | Select-Object Name
}
else {
    Write-Host "No unassociated public IP candidates found." -ForegroundColor Green
}

# Review customer-managed storage accounts.
Write-Host "`n=== STORAGE AUDIT ===" -ForegroundColor Cyan
if ($storage.Count -eq 0) {
    Write-Host "No storage accounts in lab resource group." -ForegroundColor Green
}
else {
    Write-Warning "Review storage account requirements."
    $storage | Select-Object StorageAccountName,
        @{Name="SKU";Expression={$_.Sku.Name}}
}

# Verify the Boot Diagnostics remediation.
Write-Host "`n=== BOOT DIAGNOSTICS AUDIT ===" -ForegroundColor Cyan
foreach ($vm in $vms) {
    $diag = $vm.DiagnosticsProfile.BootDiagnostics
    if ($diag.Enabled -and -not $diag.StorageUri) {
        Write-Host "$($vm.Name): Azure Managed" -ForegroundColor Green
    }
    else {
        Write-Warning "$($vm.Name): Review Boot Diagnostics configuration."
    }
}
Write-Host "`nCloudOps Guardian Audit Complete" -ForegroundColor Cyan
