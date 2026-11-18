# Project 02 — Azure Resource Ownership Audit

**Complete**

## Project overview

When an application goes down, the support team needs to know who to call. I built this lab around an Azure subscription where some resource groups were missing an owner, an environment, or a cost center.

I wrote a PowerShell script that checks those three fields and produces a report I can export to CSV. In the lab, a simulated application registry confirms Inventory’s owner and cost center. The script can preview that specific fix, then apply it while preserving the group’s existing tags. Legacy stays on the report for follow-up because its owner still needs to be confirmed.

My success criteria are a before-and-after report that shows Inventory passing, its existing tags intact, and Legacy still flagged.

## Reproduce the lab

The lab uses three empty resource groups to represent Payroll, Inventory, and Legacy. To reproduce the setup, open this folder in PowerShell 7 with the Az modules installed, or use Azure Cloud Shell in PowerShell mode. Sign in with `Connect-AzAccount` if needed and select a lab subscription where you can create, tag, and delete resource groups.

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

Inventory should retain `Application=Inventory` and `Environment=Test`. The audit checks whether the three required tags have values at the resource group level. I’ll add my observed results and cleanup status after running the lab in Azure.

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
