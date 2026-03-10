# Arc SQL SA Policy

This repo deploys and remediates a custom Azure Policy that sets Arc-enabled SQL Server extension `LicenseType` to `Paid` (Software Assurance/Azure benefit).

## What Is In This Repo

- `azurepolicy.json`: Custom policy definition (DeployIfNotExists).
- `deployment.ps1`: Creates/updates the policy definition and policy assignment.
- `start-remediation.ps1`: Starts a remediation task for the created assignment.
- `example/`: Example assets.
- `screenshots/`: Visual references.

## Prerequisites

- PowerShell with Az modules installed (`Az.Resources`).
- Logged in to Azure (`Connect-AzAccount`).
- Permissions to create policy definitions/assignments and remediation tasks at target scope.

## Deploy Policy

`ManagementGroupId` is required. `SubscriptionId` is optional.

Definition and assignment creation:

1. Download the files.

```powershell
git clone https://github.com/claestom/sa-sql-arc-policy
cd sa-sql-arc-policy
```

2. Login to Azure.

```powershell
Connect-AzAccount
```

```powershell
# Assign at management group scope
.\deployment.ps1 -ManagementGroupId "<management-group-id>"

# Assign at subscription scope (definition still created at management group)
.\deployment.ps1 -ManagementGroupId "<management-group-id>" -SubscriptionId "<subscription-id>"

# Optional: skip automatic RBAC assignment for the policy assignment identity
.\deployment.ps1 -ManagementGroupId "<management-group-id>" -SkipManagedIdentityRoleAssignment
```

`deployment.ps1` automatically grants required roles to the policy assignment managed identity at assignment scope, preventing common `PolicyAuthorizationFailed` errors during DeployIfNotExists deployments.

## Start Remediation

```powershell
# Optional but recommended: trigger policy evaluation first
Set-AzContext -Subscription "<subscription-id>"
Start-AzPolicyComplianceScan

# Remediate at management group scope
.\start-remediation.ps1 -ManagementGroupId "<management-group-id>"

# Remediate at subscription scope
.\start-remediation.ps1 -ManagementGroupId "<management-group-id>" -SubscriptionId "<subscription-id>"

# Optional: auto-grant missing permission before remediation
.\start-remediation.ps1 -ManagementGroupId "<management-group-id>" -GrantMissingPermissions
```

## Managed Identity And Roles

The policy assignment is created with `-IdentityType SystemAssigned`. Azure creates a managed identity on the assignment and uses it to apply DeployIfNotExists changes during enforcement and remediation.

Required roles:

- `Azure Extension for SQL Server Deployment` (`7392c568-9289-4bde-aaaa-b7131215889d`)
- `Reader` (`acdd72a7-3385-48ef-bd42-f606fba81ae7`)
- `Resource Policy Contributor` (required so DeployIfNotExists can create template deployments)

## Troubleshooting

If you see `PolicyAuthorizationFailed`, the policy assignment identity is missing one or more required roles at assignment scope (or inherited scope), often causing missing `Microsoft.HybridCompute/machines/extensions/write` permission.

Use one of these options:

- Re-run `deployment.ps1` (default behavior assigns `Resource Policy Contributor` automatically).
- Re-run `deployment.ps1` (default behavior assigns required roles automatically).
- Run `start-remediation.ps1 -GrantMissingPermissions` (checks and assigns missing required roles before remediation).
