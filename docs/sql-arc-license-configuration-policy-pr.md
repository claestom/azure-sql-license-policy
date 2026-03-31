# PR: Add custom Azure Policy to standardize Arc-enabled SQL Server license type

## What this policy does
This PR adds a custom Azure Policy definition (`sql-arc-license-configuration-policy.json`) that targets Arc-enabled SQL Server extensions and enforces a configured `LicenseType` value in extension settings.

- **Resource type targeted:** `Microsoft.HybridCompute/machines/extensions`
- **Extension filter:** `WindowsAgent.SqlServer` or `LinuxAgent.SqlServer` (configurable)
- **Effect:** `DeployIfNotExists` (default) or `Disabled`
- **Remediation behavior:** If a resource is in scope and considered non-compliant, the policy deploys an incremental update that merges existing extension settings with a `LicenseType` value.

In practice, this helps keep Arc-enabled SQL Server licensing state consistent at scale.

## How compliance is evaluated
The policy marks a resource as compliant when **any** of these conditions is true:

1. `LicenseType` already equals the configured target value (`targetLicenseType`), or
2. `LicenseType` is missing and `Unspecified` is **not** included in `licenseTypesToOverwrite`, or
3. Current `LicenseType` is one of `Paid`, `PAYG`, or `LicenseOnly` and that value is **not** included in `licenseTypesToOverwrite`.

If none of the above apply, the resource is treated as non-compliant and the deployment sets `LicenseType` to the target value.

## Parameters
| Parameter | Type | Default | Allowed values | Purpose |
|---|---|---|---|---|
| `effect` | String | `DeployIfNotExists` | `DeployIfNotExists`, `Disabled` | Enables or disables policy execution. |
| `sqlServerExtensionType` | String | `WindowsAgent.SqlServer` | `WindowsAgent.SqlServer`, `LinuxAgent.SqlServer` | Selects which Arc SQL Server extension type is targeted. |
| `targetLicenseType` | String | `Paid` | `Paid`, `PAYG` | License type to enforce on targeted resources. |
| `licenseTypesToOverwrite` | Array | `['Unspecified','Paid','PAYG','LicenseOnly']` | `Unspecified`, `Paid`, `PAYG`, `LicenseOnly` | Controls which existing/missing states are eligible for overwrite. |

## RBAC required for remediation
The policy includes these `roleDefinitionIds` for remediation deployment:

- `7392c568-9289-4bde-aaaa-b7131215889d`
- `acdd72a7-3385-48ef-bd42-f606fba81ae7`

At assignment time, the managed identity used by policy remediation must have permissions that allow updating Arc extension resources in scope.

## Example scenarios
### 1) Enforce one value everywhere (strict standardization)
- `effect`: `DeployIfNotExists`
- `targetLicenseType`: `Paid`
- `licenseTypesToOverwrite`: `['Unspecified','Paid','PAYG','LicenseOnly']`

**Outcome:** All in-scope resources are driven to `LicenseType = Paid`.

### 2) Set only when missing (non-disruptive baseline)
- `effect`: `DeployIfNotExists`
- `targetLicenseType`: `Paid`
- `licenseTypesToOverwrite`: `['Unspecified']`

**Outcome:** Only resources where `LicenseType` is missing are updated; existing explicit values are preserved.

### 3) Migrate from Paid to PAYG, leave others untouched
- `effect`: `DeployIfNotExists`
- `targetLicenseType`: `PAYG`
- `licenseTypesToOverwrite`: `['Paid']`

**Outcome:** Only resources currently set to `Paid` are updated to `PAYG`; missing and other states are left as-is.

### 4) Linux-only rollout
- `sqlServerExtensionType`: `LinuxAgent.SqlServer`
- Other parameters as needed for rollout strategy.

**Outcome:** Policy applies only to Arc-enabled SQL Server Linux extension resources.

## Notes for reviewers
- The policy uses `evaluationDelay: AfterProvisioningSuccess` to avoid acting before provisioning completes.
- Deployment mode is `incremental` and merges existing settings with the target `LicenseType`, minimizing unrelated configuration changes.
- The policy display name references "License With Software Assurance" while the enforced values are extension `LicenseType` values (`Paid`/`PAYG`).
