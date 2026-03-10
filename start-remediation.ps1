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
  [string]$RemediationName = "remediate-sql-arc-sa-license",

  [Parameter(Mandatory = $false)]
  [ValidateSet('ExistingNonCompliant', 'ReEvaluateCompliance')]
  [string]$ResourceDiscoveryMode,

  [Parameter(Mandatory = $false)]
  [switch]$GrantMissingPermissions
)

$AssignmentScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"

if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
  $AssignmentScope = "/subscriptions/$SubscriptionId"
}

if (-not $PSBoundParameters.ContainsKey('ResourceDiscoveryMode')) {
  # Re-evaluate is supported at subscription scope and below.
  if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
    $ResourceDiscoveryMode = 'ReEvaluateCompliance'
  }
  else {
    $ResourceDiscoveryMode = 'ExistingNonCompliant'
  }
}

# Validate assignment exists before creating remediation.
$PolicyAssignment = Get-AzPolicyAssignment -Scope $AssignmentScope -Name $PolicyAssignmentName -ErrorAction Stop

$requiredRoleNames = @(
  'Azure Extension for SQL Server Deployment'
  'Reader'
  'Resource Policy Contributor'
)
$principalId = $PolicyAssignment.IdentityPrincipalId

if ([string]::IsNullOrEmpty($principalId)) {
  throw "Policy assignment identity principal ID is empty. Cannot verify required roles."
}

$missingRoles = @()

foreach ($requiredRoleName in $requiredRoleNames) {
  $requiredRole = Get-AzRoleAssignment `
    -ObjectId $principalId `
    -RoleDefinitionName $requiredRoleName `
    -Scope $AssignmentScope `
    -ErrorAction SilentlyContinue

  if (-not $requiredRole) {
    $missingRoles += $requiredRoleName
  }
}

if ($missingRoles.Count -gt 0) {
  if ($GrantMissingPermissions) {
    foreach ($missingRole in $missingRoles) {
      New-AzRoleAssignment `
        -ObjectId $principalId `
        -RoleDefinitionName $missingRole `
        -Scope $AssignmentScope `
        -ErrorAction Stop | Out-Null

      Write-Output "Assigned '$missingRole' to policy assignment identity ($principalId) at scope $AssignmentScope."
    }
  }
  else {
    throw "Missing required roles [$($missingRoles -join ', ')] for policy assignment identity ($principalId) at scope $AssignmentScope. Re-run with -GrantMissingPermissions or assign the roles manually."
  }
}

$CommonParams = @{
  Name = $RemediationName
  PolicyAssignmentId = $PolicyAssignment.Id
  Scope = $AssignmentScope
  ResourceDiscoveryMode = $ResourceDiscoveryMode
}

if (Get-Command -Name Start-AzPolicyRemediation -ErrorAction SilentlyContinue) {
  Start-AzPolicyRemediation @CommonParams
}
elseif (Get-Command -Name New-AzPolicyRemediation -ErrorAction SilentlyContinue) {
  New-AzPolicyRemediation @CommonParams
}
else {
  throw "Neither Start-AzPolicyRemediation nor New-AzPolicyRemediation is available. Install/update Az.PolicyInsights."
}
