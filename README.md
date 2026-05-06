# SQL License Type Configuration with Azure Policy

This repo contains custom Azure Policy solutions to configure and enforce the `LicenseType` property on SQL resources in Azure. Each subfolder targets a different SQL resource type and includes its own policy definition, deployment scripts, and documentation.

## Solutions

| Folder | Resource Type | Description |
|---|---|---|
| [`sql-arc/`](sql-arc/) | Arc-enabled SQL Server | Configures and enforces `LicenseType` on the Arc-enabled SQL Server extension (`Microsoft.HybridCompute/machines/extensions`). |
| [`sql-mi/`](sql-mi/) | SQL Managed Instance | Configures and enforces `LicenseType` on Azure SQL Managed Instances (`Microsoft.Sql/managedInstances`). |
| [`sql-iaas/`](sql-iaas/) | SQL Server on Azure VMs | Configures and enforces `sqlServerLicenseType` on SQL Server on Azure Virtual Machines (`Microsoft.SqlVirtualMachine/sqlVirtualMachines`). |
| [`sql-paas/`](sql-paas/) | Azure SQL Database | Configures and enforces `licenseType` on Azure SQL Databases (`Microsoft.Sql/servers/databases`). |

## Prerequisites

- PowerShell with Az modules installed (`Az.Resources`).
- Logged in to Azure (`Connect-AzAccount`).
- Permissions to create policy definitions/assignments and remediation tasks at target scope.

## Getting Started

Navigate to the relevant subfolder for your resource type and follow the README instructions there.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the [MIT License](LICENSE).