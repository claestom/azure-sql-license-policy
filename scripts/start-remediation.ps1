param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagementGroupId,

  [Parameter(Mandatory = $false)]
  [ValidateSet('Windows', 'Linux', 'Both')]
  [string]$ExtensionType = 'Both',

  [Parameter(Mandatory = $true)]
  [ValidateSet('Paid', 'PAYG')]
  [string]$TargetLicenseType,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$PolicyAssignmentName,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$RemediationName,

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

$ExtensionTypes = if ($ExtensionType -eq 'Both') {
  @('Windows', 'Linux')
}
else {
  @($ExtensionType)
}

$LicenseToken = if ($TargetLicenseType -eq 'PAYG') { 'payg' } else { 'sa' }

foreach ($CurrentExtensionType in $ExtensionTypes) {
  $PlatformToken = $CurrentExtensionType.ToLowerInvariant()

  $CurrentPolicyAssignmentName = if ($PSBoundParameters.ContainsKey('PolicyAssignmentName') -and $ExtensionType -ne 'Both') {
    $PolicyAssignmentName
  }
  else {
    "sql-arc-$LicenseToken-$PlatformToken"
  }

  $CurrentRemediationName = if ($PSBoundParameters.ContainsKey('RemediationName') -and $ExtensionType -ne 'Both') {
    $RemediationName
  }
  else {
    "remediate-sql-arc-$LicenseToken-$PlatformToken"
  }

  $CurrentResourceDiscoveryMode = if ($PSBoundParameters.ContainsKey('ResourceDiscoveryMode')) {
    $ResourceDiscoveryMode
  }
  elseif ($PSBoundParameters.ContainsKey('SubscriptionId')) {
    'ReEvaluateCompliance'
  }
  else {
    'ExistingNonCompliant'
  }

  Write-Output "--- Starting remediation for ExtensionType: $CurrentExtensionType ---"

  # Validate assignment exists before creating remediation.
  $PolicyAssignmentObj = Get-AzPolicyAssignment -Scope $AssignmentScope -Name $CurrentPolicyAssignmentName -ErrorAction Stop

  $requiredRoleNames = @(
    'Azure Extension for SQL Server Deployment'
    'Reader'
    'Resource Policy Contributor'
  )
  $principalId = $PolicyAssignmentObj.IdentityPrincipalId

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
    Name                  = $CurrentRemediationName
    PolicyAssignmentId    = $PolicyAssignmentObj.Id
    Scope                 = $AssignmentScope
    ResourceDiscoveryMode = $CurrentResourceDiscoveryMode
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

  Write-Output "--- Completed remediation for ExtensionType: $CurrentExtensionType ---"
}
