# Audit the three lab groups. Add -ApplyApprovedFix to update Inventory.
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
$requiredTags = 'Owner', 'Environment', 'CostCenter'

$report = foreach ($workload in 'payroll', 'inventory', 'legacy') {
    $group = Get-AzResourceGroup -Name "$Prefix-$workload" -DefaultProfile $context
    $tags = $group.Tags ?? @{}

    # $_ is the current tag name. Missing or blank values count as gaps.
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

if ($ApplyApprovedFix -and $PSCmdlet.ShouldProcess("$Prefix-inventory", 'Merge approved Inventory tags')) {
    # The simulated application registry confirms Inventory ownership.
    # Merge preserves existing keys such as Application and Environment.
    # Legacy stays flagged until its owner is confirmed.
    $inventory = Get-AzResourceGroup -Name "$Prefix-inventory" -DefaultProfile $context
    Update-AzTag -ResourceId $inventory.ResourceId -Operation Merge -Tag @{
        Owner = 'SupplyChainIT'
        CostCenter = 'OPS-210'
    } -DefaultProfile $context | Out-Null
}

# Rerun the audit after applying the fix to verify the new tag values.
$report
