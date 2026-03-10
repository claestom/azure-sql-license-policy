param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagementGroupId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$SubscriptionId
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
  New-AzPolicyAssignment `
  -Name $PolicyAssignmentName `
  -DisplayName "Set Arc-enabled SQL Server license type to 'License With Software Assurance'" `
  -PolicyDefinition $Policy `
  -Scope $AssignmentScope `
  -Location 'westeurope' `
  -IdentityType 'SystemAssigned'

# Optional use subscriptions instead of management groups.
# or "/subscriptions/<SubscriptionId>"