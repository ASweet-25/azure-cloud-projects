<#
.SYNOPSIS
  Start, stop, or inspect the Azure Windows Active Directory lab.
.DESCRIPTION
  Targets dc01, pc02, and optionally their dedicated public IP resources in RG-WINDOWS-LAB.
  - Stop: deallocates pc02 first, then dc01.
  - Start: restores selected public IPs if requested, starts dc01, checks AD/DNS, then starts pc02.
  - Status: shows VM power states, public IPs, retained disks, Boot Diagnostics, and lab storage accounts.

  Your disks, domain data, private IPs, NSGs, VNet, NICs and Tailscale installation are retained.
  Public IP deletion is OPTIONAL, not the default. The recreated public IPv4 may be different.
  pc02 public IP is created only when explicitly requested via -ManagePc02PublicIp.

.EXAMPLE
  ./Azure-WindowsLab-v4.ps1 -Action Status
.EXAMPLE
  ./Azure-WindowsLab-v4.ps1 -Action Stop -WhatIf
.EXAMPLE
  ./Azure-WindowsLab-v4.ps1 -Action Stop
.EXAMPLE
  ./Azure-WindowsLab-v4.ps1 -Action Stop -ManageDc01PublicIp -ManagePc02PublicIp -WhatIf
.EXAMPLE
  ./Azure-WindowsLab-v4.ps1 -Action Stop -ManageDc01PublicIp -ManagePc02PublicIp
.EXAMPLE
  ./Azure-WindowsLab-v4.ps1 -Action Start -ManageDc01PublicIp -ManagePc02PublicIp
.NOTES
  PowerShell 7, Az.Accounts, Az.Compute, Az.Network, Az.Storage. Run on Mac in VS Code.
  Boot Diagnostics and storage checks are read-only; no automatic remediation or deletion.
  Connect-AzAccount and select the correct subscription first.
  Does not remove all Azure costs: disks, snapshots/backups, monitoring and other resources may bill.
  Only manage the IP after checking dc01 needs it for outbound Tailscale connectivity.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Status','Stop','Start')]
    [string]$Action,

    [switch]$ManageDc01PublicIp,

    [switch]$ManagePc02PublicIp
)

$ErrorActionPreference = 'Stop'
$rg = 'RG-WINDOWS-LAB'
$dcName = 'dc01'
$pcName = 'pc02'
# IP names must be dedicated to the specified VM, not shared with Bastion/NAT.
$managedIPs = @(
    [pscustomobject]@{ Vm = $dcName; Name = 'PIP-DC01'; Enabled = [bool]$ManageDc01PublicIp }
    [pscustomobject]@{ Vm = $pcName; Name = 'PIP-PC02'; Enabled = [bool]$ManagePc02PublicIp }
)

# Avoid modifying the wrong subscription or resource group.
$ctx = Get-AzContext
if (-not $ctx) { throw 'Not signed into Azure. Run Connect-AzAccount first.' }
Write-Host "Subscription : $($ctx.Subscription.Name) ($($ctx.Subscription.Id))" -ForegroundColor Cyan
Write-Host "Resource group: $rg | Action: $Action | Manage DC public IP: $ManageDc01PublicIp | Manage PC public IP: $ManagePc02PublicIp" -ForegroundColor Cyan

$null = Get-AzResourceGroup -Name $rg
$dc = Get-AzVM -ResourceGroupName $rg -Name $dcName
$pc = Get-AzVM -ResourceGroupName $rg -Name $pcName
if ($dc.Location -ne $pc.Location) { throw 'VMs are in different regions; review the script.' }

function Get-LabPowerState([string]$name) {
    # Some Az.Compute versions do not populate the top-level PowerState field.
    # Read the instance view Statuses collection and fail explicitly if absent.
    $vmStatus = Get-AzVM -ResourceGroupName $rg -Name $name -Status
    $power = @($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' } | Select-Object -First 1)
    if ($power.Count -eq 0) {
        throw "Unable to determine power state for $name. Check Get-AzVM -Status output."
    }
    return $power[0].DisplayStatus
}

function Get-LabNic([string]$name) {
    $vm = Get-AzVM -ResourceGroupName $rg -Name $name
    $refs = @($vm.NetworkProfile.NetworkInterfaces)
    if ($refs.Count -ne 1) { throw "$name NIC count changed; inspect manually." }
    $id = $refs[0].Id
    $nicRg = [regex]::Match($id, '/resourceGroups/([^/]+)/', 'IgnoreCase').Groups[1].Value
    if ($nicRg -ine $rg) { throw "$name NIC is outside $rg." }
    $nic = Get-AzNetworkInterface -ResourceGroupName $rg -Name (($id -split '/')[-1])
    if (@($nic.IpConfigurations).Count -ne 1) { throw "$name has multiple IP configurations; inspect manually." }
    return $nic
}

function Get-ManagedPip([string]$name) {
    Get-AzPublicIpAddress -ResourceGroupName $rg -Name $name -ErrorAction SilentlyContinue
}

function Assert-ManagedIp([string]$vmName, [string]$pipName) {
    $vm = Get-AzVM -ResourceGroupName $rg -Name $vmName
    $nic = Get-LabNic $vmName
    $pip = Get-ManagedPip $pipName
    $attached = $nic.IpConfigurations[0].PublicIpAddress
    if ($attached -and (($attached.Id -split '/')[-1] -ine $pipName)) {
        throw "$vmName already has a DIFFERENT public IP; refusing to replace it."
    }
    if ($pip) {
        if ($pip.Location -ine $vm.Location) { throw "$pipName is in a different region." }
        if ($pip.NatGateway) { throw "$pipName belongs to NAT Gateway." }
        if ($pip.IpConfiguration -and $pip.IpConfiguration.Id -notlike "$($nic.Id)/*") {
            throw "$pipName is attached elsewhere; refusing to change."
        }
    }
    return @{ Vm=$vm; Nic=$nic; Pip=$pip }
}

function Remove-ManagedIp([string]$vmName, [string]$pipName) {
    $state = Assert-ManagedIp $vmName $pipName
    $nic = $state.Nic
    if ($nic.IpConfigurations[0].PublicIpAddress) {
        if ($PSCmdlet.ShouldProcess($nic.Name, "Detach $pipName")) {
            $nic.IpConfigurations[0].PublicIpAddress = $null
            $nic | Set-AzNetworkInterface | Out-Null
            Write-Host "Detached $pipName from $vmName."
        }
    }
    $pip = Get-ManagedPip $pipName
    if ($pip) {
        if ($pip.IpConfiguration -or $pip.NatGateway) { throw "$pipName is still associated. Not deleting." }
        if ($PSCmdlet.ShouldProcess($pipName, 'DELETE dedicated public IP (recreated address may change)')) {
            Remove-AzPublicIpAddress -ResourceGroupName $rg -Name $pipName -Force | Out-Null
            Write-Host "Deleted $pipName." -ForegroundColor Green
        }
    }
}

function Restore-ManagedIp([string]$vmName, [string]$pipName) {
    $state = Assert-ManagedIp $vmName $pipName
    $nic = $state.Nic
    $pip = $state.Pip
    if ($nic.IpConfigurations[0].PublicIpAddress) {
        Write-Host "$pipName already attached to $vmName."
        return
    }
    if (-not $pip) {
        if ($PSCmdlet.ShouldProcess($pipName, 'Create Standard static IPv4 public IP')) {
            $pip = New-AzPublicIpAddress -ResourceGroupName $rg -Name $pipName `
                -Location $state.Vm.Location -Sku Standard -AllocationMethod Static `
                -IpAddressVersion IPv4
        }
    }
    if ($pip) {
        if ($pip.IpConfiguration -or $pip.NatGateway) { throw "$pipName is already in use." }
        if ($PSCmdlet.ShouldProcess($nic.Name, "Attach $pipName to $vmName")) {
            $nic.IpConfigurations[0].PublicIpAddress = $pip
            $nic | Set-AzNetworkInterface | Out-Null
            Write-Host "Attached $pipName to $vmName." -ForegroundColor Green
        }
    }
}

function Show-LabStatus {
    Write-Host "`n=== VMs ===" -ForegroundColor Cyan
    $states = foreach ($name in @($dcName, $pcName)) {
        [pscustomobject]@{ VM = $name; PowerState = (Get-LabPowerState $name) }
    }
    $states | Format-Table -AutoSize | Out-Host

    Write-Host '=== Public IPs in resource group ===' -ForegroundColor Cyan
    $ips = @(Get-AzPublicIpAddress -ResourceGroupName $rg)
    if ($ips.Count -eq 0) { Write-Host 'None' }
    else {
        $ips | Select-Object Name, IpAddress,
            @{Name='AttachedTo';Expression={$_.IpConfiguration.Id}} |
            Format-Table -AutoSize | Out-Host
    }

    Write-Host '=== Managed disks (retained and potentially billable) ===' -ForegroundColor Cyan
    Get-AzDisk -ResourceGroupName $rg |
        Select-Object Name, DiskSizeGB, Sku, DiskState |
        Format-Table -AutoSize | Out-Host
    # Detect diagnostic configuration drift without changing either VM.
    Write-Host "`n=== Boot Diagnostics ===" -ForegroundColor Cyan
    $diagnostics = foreach ($name in @($dcName, $pcName)) {
        $vm = Get-AzVM -ResourceGroupName $rg -Name $name
        $diag = $vm.DiagnosticsProfile.BootDiagnostics
        $mode = if (-not $diag.Enabled) { 'Disabled' }
                elseif ($diag.StorageUri) { 'Custom Storage' }
                else { 'Azure Managed' }
        [pscustomobject]@{ VM = $name; DiagnosticsMode = $mode }
    }
    $diagnostics | Format-Table -AutoSize | Out-Host
    foreach ($item in $diagnostics) {
        if ($item.DiagnosticsMode -ne 'Azure Managed') {
            Write-Warning "$($item.VM): expected Azure-managed Boot Diagnostics. Review configuration."
        }
    }

    # Check customer-managed storage in this lab only; Cloud Shell is outside scope.
    Write-Host "`n=== Storage Accounts ===" -ForegroundColor Cyan
    $accounts = @(Get-AzStorageAccount -ResourceGroupName $rg)
    if ($accounts.Count -eq 0) {
        Write-Host 'No customer-managed storage accounts in lab.' -ForegroundColor Green
    } else {
        $accounts | Select-Object StorageAccountName, Location,
            @{Name='SKU';Expression={$_.Sku.Name}} |
            Format-Table -AutoSize | Out-Host
        Write-Warning 'Customer-managed storage found. Review dependencies and costs; do not delete automatically.'
    }

    Write-Warning 'Deallocated compute stops VM compute charges, not disk, public IP, backup, storage or monitoring charges.'
}

# Dry-run deliberately plans without actually deallocating resources.
if ($WhatIfPreference -and $Action -ne 'Status') {
    Write-Host "`nDRY RUN: no changes" -ForegroundColor Yellow
    foreach ($item in $managedIPs | Where-Object Enabled) {
        $null = Assert-ManagedIp $item.Vm $item.Name
    }
    if ($Action -eq 'Stop') {
        Write-Host 'Would deallocate pc02, then dc01.'
        foreach ($item in $managedIPs | Where-Object Enabled) {
            Write-Host "Would detach and delete $($item.Name) after both VMs deallocated."
        }
    } else {
        foreach ($item in $managedIPs | Where-Object Enabled) {
            Write-Host "Would recreate/reattach $($item.Name) to $($item.Vm)."
        }
        Write-Host 'Would start dc01, check AD services, then start pc02.'
    }
    Show-LabStatus
    return
}

switch ($Action) {
    'Status' { Show-LabStatus }
    'Stop' {
        # Verify all opted-in IPs BEFORE shutting down anything.
        foreach ($item in $managedIPs | Where-Object Enabled) {
            $null = Assert-ManagedIp $item.Vm $item.Name
        }
        foreach ($name in @($pcName, $dcName)) {
            $state = Get-LabPowerState $name
            if ($state -eq 'VM deallocated') {
                Write-Host "$name already deallocated."
                continue
            }
            if ($PSCmdlet.ShouldProcess($name, 'Stop and deallocate Azure VM')) {
                Stop-AzVM -ResourceGroupName $rg -Name $name -Force | Out-Null
                $state = Get-LabPowerState $name
                if ($state -ne 'VM deallocated') { throw "$name not deallocated. Current state: $state" }
                Write-Host "$name deallocated." -ForegroundColor Green
            }
        }
        if (@($managedIPs | Where-Object Enabled).Count -gt 0) {
            if ((Get-LabPowerState $dcName) -ne 'VM deallocated' -or
                (Get-LabPowerState $pcName) -ne 'VM deallocated') {
                throw 'Both VMs must be deallocated before public IP removal.'
            }
            foreach ($item in $managedIPs | Where-Object Enabled) {
                Remove-ManagedIp $item.Vm $item.Name
            }
        }
        Show-LabStatus
    }
    'Start' {
        # Restore egress attachments BEFORE starting either VM.
        foreach ($item in $managedIPs | Where-Object Enabled) {
            $null = Assert-ManagedIp $item.Vm $item.Name
        }
        foreach ($item in $managedIPs | Where-Object Enabled) {
            Restore-ManagedIp $item.Vm $item.Name
        }

        if ((Get-LabPowerState $dcName) -ne 'VM running') {
            if ($PSCmdlet.ShouldProcess($dcName, 'Start domain controller')) {
                Start-AzVM -ResourceGroupName $rg -Name $dcName | Out-Null
                Write-Host 'Started dc01.' -ForegroundColor Green
            }
        } else { Write-Host 'dc01 already running.' }

        # A running VM is not necessarily a usable AD domain controller.
        # Use Azure Run Command from the Mac, so this check does not rely on RDP/Tailscale.
        Write-Host 'Checking dc01 AD DS, Netlogon and DNS services...' -ForegroundColor Cyan
        $ready = $false
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try {
                $result = Invoke-AzVMRunCommand -ResourceGroupName $rg -VMName $dcName `
                    -CommandId 'RunPowerShellScript' -ScriptString @'
$names = @('DNS','NTDS','Netlogon')
$services = Get-Service -Name $names -ErrorAction Stop
if (@($services | Where-Object Status -ne 'Running').Count -eq 0) {
    Write-Output 'LAB_DC_READY'
} else {
    throw 'AD DS/DNS services not yet ready.'
}
'@
                $messages = ($result.Value | ForEach-Object { $_.Message }) -join "`n"
                if ($messages -match 'LAB_DC_READY' -and $messages -notmatch 'not yet ready') {
                    $ready = $true
                    break
                }
            } catch {
                Write-Warning "DC readiness check $attempt failed: $($_.Exception.Message)"
            }
            if ($attempt -lt 6) { Start-Sleep -Seconds 15 }
        }
        if (-not $ready) {
            throw 'dc01 AD/DNS readiness could not be verified. pc02 was NOT started. Check dc01 manually.'
        }
        Write-Host 'dc01 services are running.' -ForegroundColor Green

        if ((Get-LabPowerState $pcName) -ne 'VM running') {
            if ($PSCmdlet.ShouldProcess($pcName, 'Start domain-joined workstation')) {
                Start-AzVM -ResourceGroupName $rg -Name $pcName | Out-Null
                Write-Host 'Started pc02.' -ForegroundColor Green
            }
        } else { Write-Host 'pc02 already running.' }
        Show-LabStatus
        Write-Warning 'Validate domain discovery and Tailscale after startup. pc02 requires its own outbound internet method (e.g. PIP-PC02). Keep public inbound RDP denied.'
    }
}
