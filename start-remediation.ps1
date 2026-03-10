param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagementGroupId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$PolicyAssignmentName = "sql-arc-sa-license",

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$RemediationName = "remediate-sql-arc-sa-license"
)

$AssignmentScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"

if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
  $AssignmentScope = "/subscriptions/$SubscriptionId"
}

# Validate assignment exists before creating remediation.
$PolicyAssignment = Get-AzPolicyAssignment -Scope $AssignmentScope -Name $PolicyAssignmentName -ErrorAction Stop

New-AzPolicyRemediation `
  -Name $RemediationName `
  -PolicyAssignmentId $PolicyAssignment.ResourceId `
  -Scope $AssignmentScope `
  -ResourceDiscoveryMode ReEvaluateCompliance
