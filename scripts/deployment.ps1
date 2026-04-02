param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagementGroupId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $false)]
  [ValidateSet('Windows', 'Linux', 'Both')]
  [string]$ExtensionType = 'Both',

  [Parameter(Mandatory = $true)]
  [ValidateSet('Paid', 'PAYG')]
  [string]$TargetLicenseType,

  [Parameter(Mandatory = $false)]
  [ValidateSet('Unspecified', 'Paid', 'PAYG', 'LicenseOnly')]
  [string[]]$LicenseTypesToOverwrite = @('Unspecified', 'Paid', 'PAYG', 'LicenseOnly'),

  [Parameter(Mandatory = $false)]
  [switch]$SkipManagedIdentityRoleAssignment
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

$PolicyJsonPath = Join-Path $PSScriptRoot '..\policy\azurepolicy.json'
$LicenseToken = if ($TargetLicenseType -eq 'PAYG') { 'payg' } else { 'sa' }

foreach ($CurrentExtensionType in $ExtensionTypes) {
  $SqlServerExtensionType = if ($CurrentExtensionType -eq 'Linux') {
    'LinuxAgent.SqlServer'
  }
  else {
    'WindowsAgent.SqlServer'
  }

  $PlatformToken = $CurrentExtensionType.ToLowerInvariant()

  $PolicyDefinitionName = "activate-sql-arc-$LicenseToken-$PlatformToken"
  $PolicyAssignmentName = "sql-arc-$LicenseToken-$PlatformToken"

  if ($TargetLicenseType -eq 'PAYG') {
    $PolicyDefinitionDisplayName = "Arc-enabled SQL Server (ExtensionType: $CurrentExtensionType) license type to 'Pay-as-you-go'"
    $PolicyAssignmentDisplayName = "Arc-enabled SQL Server (ExtensionType: $CurrentExtensionType) license type to 'Pay-as-you-go'"
  }
  else {
    $PolicyDefinitionDisplayName = "Set Arc-enabled SQL Server (ExtensionType: $CurrentExtensionType) license type to 'License With Software Assurance'"
    $PolicyAssignmentDisplayName = "Set Arc-enabled SQL Server (ExtensionType: $CurrentExtensionType) license type to 'License With Software Assurance'"
  }

  Write-Output "--- Deploying policy for ExtensionType: $CurrentExtensionType ---"

  #Create policy definition
  New-AzPolicyDefinition `
    -Name $PolicyDefinitionName `
    -DisplayName $PolicyDefinitionDisplayName `
    -Policy $PolicyJsonPath `
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
      targetLicenseType      = $TargetLicenseType
      licenseTypesToOverwrite = $LicenseTypesToOverwrite
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

  Write-Output "--- Completed deployment for ExtensionType: $CurrentExtensionType ---"
}