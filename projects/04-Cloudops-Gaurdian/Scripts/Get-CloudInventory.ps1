
# CloudOps Guardian - Azure Resource Inventory
# Purpose: Collect an operational baseline of Azure resources.

# Stop if a command encounters an error.
$ErrorActionPreference = "Stop"

# Verify that we are connected to Azure.
$context = Get-AzContext

if (-not $context) {
    throw "Not connected to Azure. Run Connect-AzAccount."
}

# Display the subscription being inspected.
Write-Host "`nSubscription: $($context.Subscription.Name)"
Write-Host "Report Date: $(Get-Date)"

# Collect all visible Azure resources.
$resources = Get-AzResource

# Display the total number of resources.
Write-Host "`nTotal Resources: $($resources.Count)"

# Group resources by type and count them.
Write-Host "`nRESOURCE SUMMARY" -ForegroundColor Cyan

$resources |
    Group-Object ResourceType |
    Select-Object Count, Name |
    Format-Table -AutoSize

# Display virtual machine power states.
Write-Host "`nVIRTUAL MACHINE STATUS" -ForegroundColor Cyan

Get-AzVM -Status |
    Select-Object Name, ResourceGroupName, PowerState |
    Format-Table -AutoSize

# Identify resources without tags.
Write-Host "`nUNTAGGED RESOURCES" -ForegroundColor Yellow

$resources |
    Where-Object { -not $_.Tags } |
    Select-Object Name, ResourceType |
    Format-Table -AutoSize

Write-Host "`nInventory Complete" -ForegroundColor Green
