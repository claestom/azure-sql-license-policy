#Create policy definition
New-AzPolicyDefinition `
  -Name "activate-azure-benefits-for-sql-arc-servers" `
  -DisplayName "Configure license to software assurance and activate Azure benefits for Arc-enabled SQL Servers" `
  -Policy 'azurepolicy.json' `
  -ManagementGroupName "<MyManagementGroup>" `
  -Mode Indexed

#Assign policy definition
$Policy = Get-AzPolicyDefinition -Name 'activate-azure-benefits-for-sql-arc-servers' -ManagementGroupName "<ScopeOfDefinitionCreation>"
  New-AzPolicyAssignment `
  -Name "activate-sql-arc-benefits" `
  -DisplayName "Configure license to software assurance and activate Azure benefits for Arc-enabled SQL Servers" `
  -PolicyDefinition $Policy `
  -Scope "/providers/Microsoft.Management/managementGroups/<MyManagementGroup>" ` 
  -Location 'westeurope' `
  -IdentityType 'SystemAssigned'

# Optional use subscriptions instead of management groups.
# or "/subscriptions/<SubscriptionId>"