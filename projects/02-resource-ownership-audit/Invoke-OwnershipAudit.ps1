# Run this after the setup in README.md.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [ValidatePattern('^rg-govlab-[0-9]{14}$')]
    [string]$Prefix,

    [switch]$ApplyApprovedFix
)

$ErrorActionPreference = 'Stop'
$context = Get-AzContext
if ($context.Subscription.Id -ne $SubscriptionId) {
    throw 'Select the intended lab subscription before running the audit.'
}

# Pass the verified context explicitly to keep every Azure call in scope.
$names = @('payroll', 'inventory', 'legacy') | ForEach-Object { "$Prefix-$_" }
$requiredTags = 'Owner', 'Environment', 'CostCenter'

$report = foreach ($name in $names) {
    $group = Get-AzResourceGroup -Name $name -DefaultProfile $context
    $tags = $group.Tags
    if ($null -eq $tags) { $tags = @{} }

    # Inside Where-Object, $_ is the tag name. Missing or blank counts as a gap.
    $missing = @($requiredTags | Where-Object {
        [string]::IsNullOrWhiteSpace($tags[$_])
    })

    # Returning objects makes the same results usable in a table or CSV.
    [pscustomobject]@{
        ResourceGroup = $group.ResourceGroupName
        Compliant = ($missing.Count -eq 0)
        MissingTags = ($missing -join ', ')
    }
}

if ($ApplyApprovedFix -and $PSCmdlet.ShouldProcess($names[1], 'Merge approved Inventory tags')) {
    # The simulated application registry confirms Inventory ownership.
    # Merge preserves existing keys such as Application and Environment.
    # Legacy stays flagged until its owner is confirmed.
    $inventory = Get-AzResourceGroup -Name $names[1] -DefaultProfile $context
    Update-AzTag -ResourceId $inventory.ResourceId -Operation Merge -Tag @{
        Owner = 'SupplyChainIT'
        CostCenter = 'OPS-210'
    } -DefaultProfile $context | Out-Null
}

# This report reflects the scan before any optional write. Rerun to verify.
$report
