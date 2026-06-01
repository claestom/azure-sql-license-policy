param(
  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$ManagementGroupId,

  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$SubscriptionId,

  [Parameter(Mandatory = $true)]
  [ValidateSet('LicenseIncluded', 'BasePrice')]
  [string]$TargetLicenseType,

  [Parameter(Mandatory = $false)]
  [ValidateSet('LicenseIncluded', 'BasePrice')]
  [string[]]$LicenseTypesToOverwrite = @('LicenseIncluded', 'BasePrice'),

  [Parameter(Mandatory = $false)]
  [switch]$SkipLicenseConfirmation
)

$LicenseConfirmations = @{
  'BasePrice' = "I confirm that I have a SQL Server License with Software Assurance to apply this Azure Hybrid Benefit for SQL Server."
}

if (-not $SkipLicenseConfirmation -and $LicenseConfirmations.ContainsKey($TargetLicenseType)) {
  $confirmationMessage = $LicenseConfirmations[$TargetLicenseType]
  Write-Host "`n$confirmationMessage" -ForegroundColor Yellow
  $response = Read-Host "Do you agree? (Y/N)"
  if ($response -notin @('Y', 'y', 'Yes', 'yes')) {
    Write-Output "Deployment cancelled. License confirmation was not accepted."
    return
  }
}

if (-not $PSBoundParameters.ContainsKey('ManagementGroupId')) {
  $ManagementGroupId = (Get-AzContext).Tenant.Id
  Write-Output "ManagementGroupId not specified. Using tenant root management group: $ManagementGroupId"
}

$AssignmentScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupId"

if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
  $AssignmentScope = "/subscriptions/$SubscriptionId"
}

$PolicyJsonPath = Join-Path $PSScriptRoot '..\policy\azurepolicy.json'

$LicenseToken = switch ($TargetLicenseType) {
  'LicenseIncluded' { 'payg' }
  'BasePrice'       { 'ahb' }
}

$LicenseTypeLabel = switch ($TargetLicenseType) {
  'LicenseIncluded' { 'Pay-as-you-go' }
  'BasePrice'       { 'Azure Hybrid Benefit' }
}

$PolicyDefinitionName    = "audit-sql-ssis-$LicenseToken"
$PolicyAssignmentName    = "sql-ssis-$LicenseToken"
$PolicyDefinitionDisplayName = "Audit Azure Data Factory SSIS Integration Runtime license type ('$LicenseTypeLabel')"
$PolicyAssignmentDisplayName = "Audit Azure Data Factory SSIS Integration Runtime license type ('$LicenseTypeLabel')"

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
New-AzPolicyAssignment `
  -Name $PolicyAssignmentName `
  -DisplayName $PolicyAssignmentDisplayName `
  -PolicyDefinition $Policy `
  -PolicyParameterObject @{
    targetLicenseType       = $TargetLicenseType
    licenseTypesToOverwrite = $LicenseTypesToOverwrite
  } `
  -Scope $AssignmentScope `
  -NonComplianceMessage @(
    @{
      Message = "The Azure Data Factory SSIS Integration Runtime license type is not set to '$LicenseTypeLabel'. Run scripts/start-remediation.ps1 to remediate (the underlying ARM operation requires a full IR body merge, which the script performs via Set-AzDataFactoryV2IntegrationRuntime)."
    }
  ) `
  -ErrorAction Stop
