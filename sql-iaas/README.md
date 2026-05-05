# SQL Server on Azure VMs (IaaS) License Type Configuration with Azure Policy

This solution will deploy and remediate a custom Azure Policy that configures and enforces the `sqlServerLicenseType` property on SQL Server on Azure Virtual Machines (`Microsoft.SqlVirtualMachine/sqlVirtualMachines`).

## What Is In This Folder

- `policy/azurepolicy.json`: Custom policy definition (to be created).
- `scripts/deployment.ps1`: Creates/updates the policy definition and policy assignment (to be created).
- `scripts/start-remediation.ps1`: Starts a remediation task for the created assignment (to be created).
- `docs/screenshots/`: Visual references.

## Status

> **Work in progress** — policy definition and scripts are not yet available. See the [sql-mi](../sql-mi/) folder for a working reference implementation.
