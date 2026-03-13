# Arc-enabled SQL Server Software Assurance benefits with Azure Policy

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

Parameter reference:

| Parameter | Required | Default | Allowed values | Description |
|---|---|---|---|---|
| `ManagementGroupId` | Yes | N/A | Any valid management group ID | Scope where the policy definition is created. |
| `ExtensionType` | Yes | N/A | `Windows`, `Linux` | Targets the Arc SQL extension platform. |
| `SubscriptionId` | No | Not set | Any valid subscription ID | If provided, policy assignment scope is the subscription. |
| `TargetLicenseType` | No | `Paid` | `Paid`, `PAYG` | Target `LicenseType` value to enforce. |
| `OverwriteExistingLicenseType` | No | `true` | `$true`, `$false` | `$true` overwrites non-target values; `$false` only sets when missing. |

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
# Example (includes all parameters)
.\deployment.ps1 -ManagementGroupId "<management-group-id>" -ExtensionType "Linux" -SubscriptionId "<subscription-id>" -TargetLicenseType "PAYG" -OverwriteExistingLicenseType $true
```
The above example commmand will:
* Create/update the policy definition at the management group.
* Assign that policy at the specified subscription scope.
* Target SQL Server instances running on Linux OS
* Enforce LicenseType = PAYG.
* With $true, overwrite existing non-PAYG license values.

Note: `deployment.ps1` automatically grants required roles to the policy assignment managed identity at assignment scope, preventing common `PolicyAuthorizationFailed` errors during DeployIfNotExists deployments.

## Start Remediation

Parameter reference:

| Parameter | Required | Default | Allowed values | Description |
|---|---|---|---|---|
| `ManagementGroupId` | Yes | N/A | Any valid management group ID | Used to resolve the policy definition/assignment naming context. |
| `ExtensionType` | Yes | N/A | `Windows`, `Linux` | Must match the platform used for the assignment. |
| `SubscriptionId` | No | Not set | Any valid subscription ID | If provided, remediation runs at subscription scope. |
| `TargetLicenseType` | No | `Paid` | `Paid`, `PAYG` | Must match the assignment target license type. |
| `GrantMissingPermissions` | No | `false` | Switch (`present`/`not present`) | If set, checks and assigns missing required roles before remediation. |

```powershell
# Example (includes all parameters)
.\start-remediation.ps1 -ManagementGroupId "<management-group-id>" -ExtensionType "Linux" -SubscriptionId "<subscription-id>" -TargetLicenseType "PAYG" -GrantMissingPermissions
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
