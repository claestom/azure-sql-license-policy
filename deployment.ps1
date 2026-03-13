param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagementGroupId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $true)]
  [ValidateSet('Windows', 'Linux')]
  [string]$ExtensionType,

  [Parameter(Mandatory = $false)]
  [ValidateSet('Paid', 'PAYG')]
  [string]$TargetLicenseType = 'Paid',

  [Parameter(Mandatory = $false)]
  [bool]$OverwriteExistingLicenseType = $true,

  [Parameter(Mandatory = $false)]
  [bool]$ExcludeAlreadyPayg = $false,

  [Parameter(Mandatory = $false)]
  [switch]$SkipManagedIdentityRoleAssignment
)

$AssignmentScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"

if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
  $AssignmentScope = "/subscriptions/$SubscriptionId"
}

$SqlServerExtensionType = if ($ExtensionType -eq 'Linux') {
  'LinuxAgent.SqlServer'
}
else {
  'WindowsAgent.SqlServer'
}

$PlatformToken = $ExtensionType.ToLowerInvariant()
$LicenseToken = if ($TargetLicenseType -eq 'PAYG') { 'payg' } else { 'sa' }

$PolicyDefinitionName = "activate-sql-arc-$LicenseToken-$PlatformToken"
$PolicyAssignmentName = "sql-arc-$LicenseToken-$PlatformToken"

if ($TargetLicenseType -eq 'PAYG') {
  $PolicyDefinitionDisplayName = "Arc-enabled SQL Server (ExtensionType: $ExtensionType) license type to 'Pay-as-you-go'"
  $PolicyAssignmentDisplayName = "Arc-enabled SQL Server (ExtensionType: $ExtensionType) license type to 'Pay-as-you-go'"
}
else {
  $PolicyDefinitionDisplayName = "Set Arc-enabled SQL Server (ExtensionType: $ExtensionType) license type to 'License With Software Assurance'"
  $PolicyAssignmentDisplayName = "Set Arc-enabled SQL Server (ExtensionType: $ExtensionType) license type to 'License With Software Assurance'"
}

#Create policy definition
New-AzPolicyDefinition `
  -Name $PolicyDefinitionName `
  -DisplayName $PolicyDefinitionDisplayName `
  -Policy 'azurepolicy.json' `
  -ManagementGroupName $ManagementGroupId `
  -Mode Indexed `
  -ErrorAction Stop

#Assign policy definition
$Policy = Get-AzPolicyDefinition -Name $PolicyDefinitionName -ManagementGroupName $ManagementGroupId
$PolicyAssignment = New-AzPolicyAssignment `
  -Name $PolicyAssignmentName `
  -DisplayName $PolicyAssignmentDisplayName `
  -PolicyDefinition $Policy `
  -PolicyParameterObject @{
    sqlServerExtensionType = $SqlServerExtensionType
    targetLicenseType = $TargetLicenseType
    overwriteExistingLicenseType = $OverwriteExistingLicenseType
    excludeAlreadyPayg = $ExcludeAlreadyPayg
  } `
  -Scope $AssignmentScope `
  -Location 'westeurope' `
  -IdentityType 'SystemAssigned' `
  -ErrorAction Stop

if (-not $SkipManagedIdentityRoleAssignment) {
  $requiredRoleNames = @(
    'Azure Extension for SQL Server Deployment'
    'Reader'
    'Resource Policy Contributor'
  )
  $principalId = $PolicyAssignment.IdentityPrincipalId

  if ([string]::IsNullOrEmpty($principalId)) {
    throw "Policy assignment identity principal ID is empty. Cannot assign required roles."
  }

  foreach ($requiredRoleName in $requiredRoleNames) {
    $existingRole = Get-AzRoleAssignment `
      -ObjectId $principalId `
      -RoleDefinitionName $requiredRoleName `
      -Scope $AssignmentScope `
      -ErrorAction SilentlyContinue

    if (-not $existingRole) {
      New-AzRoleAssignment `
        -ObjectId $principalId `
        -RoleDefinitionName $requiredRoleName `
        -Scope $AssignmentScope `
        -ErrorAction Stop | Out-Null

      Write-Output "Assigned '$requiredRoleName' to policy assignment identity ($principalId) at scope $AssignmentScope."
    }
    else {
      Write-Output "Policy assignment identity already has '$requiredRoleName' at scope $AssignmentScope."
    }
  }
}

# Optional use subscriptions instead of management groups.
# or "/subscriptions/<SubscriptionId>"