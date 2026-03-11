param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagementGroupId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $false)]
  [ValidateSet('WindowsAgent.SqlServer', 'LinuxAgent.SqlServer')]
  [string]$SqlServerExtensionType = 'WindowsAgent.SqlServer',

  [Parameter(Mandatory = $false)]
  [switch]$SkipManagedIdentityRoleAssignment
)

$PolicyDefinitionName = "activate-azure-benefits-for-sql-arc-servers"
$PolicyAssignmentName = "sql-arc-sa-license"
$AssignmentScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"

if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
  $AssignmentScope = "/subscriptions/$SubscriptionId"
}

#Create policy definition
New-AzPolicyDefinition `
  -Name $PolicyDefinitionName `
  -DisplayName "Set Arc-enabled SQL Server license type to 'License With Software Assurance'" `
  -Policy 'azurepolicy.json' `
  -ManagementGroupName $ManagementGroupId `
  -Mode Indexed

#Assign policy definition
$Policy = Get-AzPolicyDefinition -Name $PolicyDefinitionName -ManagementGroupName $ManagementGroupId
$PolicyAssignment = New-AzPolicyAssignment `
  -Name $PolicyAssignmentName `
  -DisplayName "Set Arc-enabled SQL Server license type to 'License With Software Assurance'" `
  -PolicyDefinition $Policy `
  -PolicyParameterObject @{
    sqlServerExtensionType = @{ value = $SqlServerExtensionType }
  } `
  -Scope $AssignmentScope `
  -Location 'westeurope' `
  -IdentityType 'SystemAssigned'

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