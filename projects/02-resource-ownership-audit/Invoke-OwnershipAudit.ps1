<#
.SYNOPSIS
    Check three Azure lab resource groups for required ownership tags.
.DESCRIPTION
    By default, the script reads Azure metadata and returns one report row per
    group. Add -ApplyApprovedFix to merge the approved tags into Inventory.
    Add -WhatIf with that switch to preview the update.
#>
# SupportsShouldProcess adds the -WhatIf and -Confirm options.
[CmdletBinding(SupportsShouldProcess)]
param(
    # The subscription ID is required and is checked against the active Azure context.
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    # The setup step creates a shared prefix with a 14-digit timestamp.
    # ValidatePattern rejects input that does not match that lab naming format.
    [Parameter(Mandatory)]
    [ValidatePattern('^rg-govlab-[0-9]{14}$')]
    [string]$Prefix,

    # A switch is off unless supplied. Leave it off for a read-only audit.
    [switch]$ApplyApprovedFix
)

# Stop on command errors so a failed lookup cannot lead to a partial report or update.
$ErrorActionPreference = 'Stop'

# Get the active Azure context and stop if it points to the wrong subscription.
$context = Get-AzContext
if ($context.Subscription.Id -ne $SubscriptionId) {
    throw 'Select the intended lab subscription before running the audit.'
}

# These are the three tag keys the business expects on each resource group.
$requiredTags = 'Owner', 'Environment', 'CostCenter'

# Scan each lab group and collect the rows emitted by the loop in $report.
$report = foreach ($workload in 'payroll', 'inventory', 'legacy') {
    # Combine the shared prefix and workload name to find the exact group.
    # -DefaultProfile passes the Azure context we already checked.
    $group = Get-AzResourceGroup -Name "$Prefix-$workload" -DefaultProfile $context
    # Tags are key/value pairs. The ?? operator uses an empty hashtable
    # if Azure returns null, so a group without tags can still be checked.
    $tags = $group.Tags ?? @{}

    # Pipe the required keys to Where-Object. Inside the filter, $_ is the
    # current key and $tags[$_] looks up its value. Keep keys with null, empty,
    # or whitespace-only values. @() keeps the result an array for .Count.
    $missing = @($requiredTags | Where-Object {
        [string]::IsNullOrWhiteSpace($tags[$_])
    })

    # Create a report row. Zero missing keys means the group passes this check.
    # -join turns the missing keys into one readable field for tables and CSVs.
    [pscustomobject]@{
        ResourceGroup = $group.ResourceGroupName
        Compliant = ($missing.Count -eq 0)
        MissingTags = ($missing -join ', ')
    }
}

# Enter the update block only if the switch was supplied and ShouldProcess
# permits the write. With -WhatIf, ShouldProcess describes the proposed update.
if ($ApplyApprovedFix -and $PSCmdlet.ShouldProcess("$Prefix-inventory", 'Merge approved Inventory tags')) {
    # Inventory is the only approved target in the simulated application registry.
    # Retrieve its full resource ID so Update-AzTag can address the exact group.
    # Legacy stays flagged until its owner is confirmed.
    $inventory = Get-AzResourceGroup -Name "$Prefix-inventory" -DefaultProfile $context
    # Merge adds or updates the two listed tags and preserves other keys such
    # as Application and Environment. Out-Null keeps the update response out
    # of the report so the output can go straight to Export-Csv.
    Update-AzTag -ResourceId $inventory.ResourceId -Operation Merge -Tag @{
        Owner = 'SupplyChainIT'
        CostCenter = 'OPS-210'
    } -DefaultProfile $context | Out-Null
}

# Return the report captured before any optional write. Rerun without the fix
# switch to verify the updated group and capture the after report.
$report
