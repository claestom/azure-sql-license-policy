# Automating Arc-enabled SQL Server software assurance benefits with Azure Policy

Azure Arc allows users to onboard their hybrid resources into Azure, such as Linus/Windows servers or SQL Servers. The onboarding can happen regardless where the resources are hosted: on-premises, multi-cloud or edge devices. 

The main benefit of onboarding resources into Azure Arc are the management capabilities from the Azure cloud that will become available: Azure Portal as the control plane, Azure Monitor, Azure Policy, Defender for Cloud... For customers that have software assurance enabled on their Windows Servers and/or SQL Servers, some additonal benefits are available. 

These being some paid services that become available at no additional cost, e.g., Azure Update Manager (priced at 5$/instance/month, but for SA customers available at no additional cost). Next to the waiving of some licensing fees for services, also additional features become available that are exclusively available to customers with software assurnace, such as: Best Practice Assessment or Remote Support.

## How to enable these benefits at scale using Azure Policy?

To activate the benefits, you need to attest in the Azure Portal that your Windows Servers and/or SQL Servers are covered by software assurance.

Today we will focus on how to do this using Azure Policy. Other options are manual enablement via the Azure Portal UI or using Powershell scripting. In this article, written by <name> it is explained how to do this for the Windows Server part, which triggered the inspiration to replicate this to the SQL Server part as well.

## How to deploy the policy?

The deployment itself will consist of 2 parts:

* Creating the Azure Policy definition and the Policy assignment
* Creating the remediaton task to make sure existing Arc-enabled SQL Servers are compliant as well

### Definition and assingment creation

...

### Remediation task creation



