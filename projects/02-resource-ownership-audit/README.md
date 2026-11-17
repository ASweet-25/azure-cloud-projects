# Project 02 — Azure Resource Ownership Audit

**Status: In progress**

## Business scenario

A support team inherited an Azure subscription and needs to know who owns each workload and which cost center it belongs to. This lab uses PowerShell to find missing tags, apply an approved fix, and report the unresolved ownership gap for follow-up.

## Run the lab

Use PowerShell 7 with Az PowerShell in VS Code, or Azure Cloud Shell in PowerShell mode. Sign in with `Connect-AzAccount` if needed. Run from this project folder in a lab subscription where you can create, tag, and remove resource groups. The lab creates three empty resource groups.

```powershell
# Select and verify the intended subscription before creating anything.
Get-AzSubscription | Format-Table Name, Id, State
$subscriptionId = Read-Host 'Enter your lab subscription ID'
$context = Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop
$context.Subscription | Format-Table Name, Id

# The timestamp gives this run a dedicated set of resource group names.
$ErrorActionPreference = 'Stop'
$prefix = "rg-govlab-$(Get-Date -Format yyyyMMddHHmmss)"
$groups = @{
    payroll   = @{ Owner = 'FinanceApps'; Environment = 'Production'; CostCenter = 'FIN-100' }
    inventory = @{ Environment = 'Test'; Application = 'Inventory' }
    legacy    = @{ Environment = 'Production'; CostCenter = 'OPS-200' }
}

foreach ($entry in $groups.GetEnumerator()) {
    New-AzResourceGroup -Name "$prefix-$($entry.Key)" -Location centralus `
        -Tag $entry.Value -DefaultProfile $context | Out-Null
}

# Use the same audit before and after the change to measure the result.
$audit = @{ SubscriptionId = $subscriptionId; Prefix = $prefix }
./Invoke-OwnershipAudit.ps1 @audit | Export-Csv ./before.csv -NoTypeInformation
./Invoke-OwnershipAudit.ps1 @audit -ApplyApprovedFix -WhatIf
./Invoke-OwnershipAudit.ps1 @audit -ApplyApprovedFix | Out-Null
./Invoke-OwnershipAudit.ps1 @audit | Export-Csv ./after.csv -NoTypeInformation

Import-Csv ./after.csv | Format-Table
(Get-AzResourceGroup -Name "$prefix-inventory" -DefaultProfile $context).Tags
```

## Expected verification

| Resource group | Before | After |
|---|---|---|
| Payroll | Pass | Pass |
| Inventory | Missing Owner and CostCenter | Pass |
| Legacy | Missing Owner | Escalate for ownership confirmation |

Inventory should retain `Application=Inventory` and `Environment=Test`. The audit checks for required tags with nonblank values. The simulated application registry supplies the approved Inventory values. Resource group tags apply to the resource group itself.

Record your observed results and cleanup status after running the lab. Review CSVs for sensitive details before sharing them.

## Cleanup

Review the groups displayed before confirming deletion.

```powershell
# Check all three dedicated groups before deleting any of them.
if ((Get-AzContext).Subscription.Id -ne $subscriptionId) {
    throw 'Switch back to the lab subscription.'
}

$names = @('payroll', 'inventory', 'legacy') | ForEach-Object { "$prefix-$_" }
foreach ($name in $names) {
    Get-AzResourceGroup -Name $name | Select-Object ResourceGroupName, Location
    if (Get-AzResource -ResourceGroupName $name) {
        throw "Unexpected resources found in $name. Review before deleting."
    }
}

foreach ($name in $names) {
    Remove-AzResourceGroup -Name $name -Confirm
}

# No rows should remain after deletion completes.
Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -in $names }
```
