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
  [switch]$Force
)

# Resolve subscriptions in scope.
# SSIS IR remediation cannot use Start-AzPolicyRemediation because the underlying
# ARM CreateOrUpdate replaces the integrationRuntime's discriminated-union
# typeProperties block. We mirror the official Microsoft sample pattern instead,
# which calls Set-AzDataFactoryV2IntegrationRuntime (it performs an internal
# GET / merge / PUT against the data plane).
if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
  $subscriptions = @([pscustomobject]@{ Id = $SubscriptionId })
}
else {
  if (-not $PSBoundParameters.ContainsKey('ManagementGroupId')) {
    $ManagementGroupId = (Get-AzContext).Tenant.Id
    Write-Output "ManagementGroupId not specified. Using tenant root management group: $ManagementGroupId"
  }
  try {
    $subscriptions = Get-AzManagementGroupSubscription -GroupId $ManagementGroupId -ErrorAction Stop
  }
  catch {
    throw "Failed to enumerate subscriptions under management group '$ManagementGroupId': $($_.Exception.Message)"
  }
}

if (-not (Get-Module -ListAvailable -Name Az.DataFactory)) {
  throw "Az.DataFactory module is required. Install with: Install-Module Az.DataFactory -Scope CurrentUser"
}
Import-Module Az.DataFactory -ErrorAction Stop

$candidates = @()

foreach ($sub in $subscriptions) {
  $subId = if ($sub.Id) { $sub.Id }
           elseif ($sub.SubscriptionId) { $sub.SubscriptionId }
           else { [string]$sub }

  try {
    Set-AzContext -SubscriptionId $subId -ErrorAction Stop | Out-Null
  }
  catch {
    Write-Warning "Skipping subscription $subId (cannot set context): $($_.Exception.Message)"
    continue
  }

  $factories = Get-AzDataFactoryV2 -ErrorAction SilentlyContinue
  foreach ($factory in $factories) {
    $irs = Get-AzDataFactoryV2IntegrationRuntime `
             -ResourceGroupName $factory.ResourceGroupName `
             -DataFactoryName  $factory.DataFactoryName `
             -ErrorAction SilentlyContinue
    foreach ($ir in $irs) {
      # Only Managed SSIS IRs have NodeSize set.
      if ($null -eq $ir.NodeSize)               { continue }
      if ($null -eq $ir.LicenseType)            { continue }
      if ($ir.LicenseType -eq $TargetLicenseType) { continue }
      if ($ir.LicenseType -notin $LicenseTypesToOverwrite) { continue }

      $candidates += [pscustomobject]@{
        SubscriptionId     = $subId
        ResourceGroupName  = $factory.ResourceGroupName
        DataFactoryName    = $factory.DataFactoryName
        Name               = $ir.Name
        CurrentLicenseType = $ir.LicenseType
        State              = $ir.State
      }
    }
  }
}

if ($candidates.Count -eq 0) {
  Write-Output "No SSIS Integration Runtimes require remediation to '$TargetLicenseType'."
  return
}

Write-Output ([Environment]::NewLine + "Found $($candidates.Count) SSIS Integration Runtime(s) to remediate to '$TargetLicenseType':")
$candidates |
  Format-Table SubscriptionId, ResourceGroupName, DataFactoryName, Name, CurrentLicenseType, State -AutoSize |
  Out-String |
  Write-Output

if (-not $Force) {
  $response = Read-Host "Proceed with remediation? (Y/N)"
  if ($response -notin @('Y', 'y', 'Yes', 'yes')) {
    Write-Output "Remediation cancelled."
    return
  }
}

foreach ($c in $candidates) {
  try {
    Set-AzContext -SubscriptionId $c.SubscriptionId -ErrorAction Stop | Out-Null
    Set-AzDataFactoryV2IntegrationRuntime `
      -ResourceGroupName $c.ResourceGroupName `
      -DataFactoryName   $c.DataFactoryName `
      -Name              $c.Name `
      -LicenseType       $TargetLicenseType `
      -Force `
      -ErrorAction Stop | Out-Null

    Write-Output "Updated $($c.DataFactoryName)/$($c.Name) from '$($c.CurrentLicenseType)' to '$TargetLicenseType' (rg=$($c.ResourceGroupName), sub=$($c.SubscriptionId))."
  }
  catch {
    Write-Warning "Failed to update $($c.DataFactoryName)/$($c.Name) (rg=$($c.ResourceGroupName), sub=$($c.SubscriptionId)): $($_.Exception.Message)"
  }
}
