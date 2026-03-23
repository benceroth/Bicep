<#
.SYNOPSIS
  Deploy the Bicep infrastructure to a target environment.

.PARAMETER Environment
  Target environment: dev, staging, or prod.

.PARAMETER Location
  Azure region for the deployment. Default: westeurope.

.PARAMETER ResourceGroup
  Name of the resource group to deploy into.

.PARAMETER AuthClientId
  (Optional) Entra ID app registration client ID for App Service auth.

.PARAMETER AuthClientSecret
  (Optional) Entra ID app registration client secret.

.EXAMPLE
  .\deploy.ps1 -Environment dev -ResourceGroup rg-myproject-dev -Location westeurope
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [string]$Location = 'westeurope',

    [string]$AuthClientId = '',

    [SecureString]$AuthClientSecret
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$templateFile = Join-Path $repoRoot 'Infrastructure' 'main.bicep'
$paramFile = Join-Path $repoRoot 'Infrastructure' 'parameters' "$Environment.bicepparam"

if (-not (Test-Path $paramFile)) {
    Write-Error "Parameter file not found: $paramFile"
    return
}

$deployParams = @(
    'deployment', 'group', 'create',
    '--resource-group', $ResourceGroup,
    '--template-file', $templateFile,
    '--parameters', "@$paramFile"
    '--name', "infra-$Environment-$(Get-Date -Format 'yyyyMMddHHmmss')"
)

if ($AuthClientId) {
    $deployParams += '--parameters'
    $deployParams += "authClientId=$AuthClientId"
}

if ($AuthClientSecret) {
    $plainSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AuthClientSecret)
    )
    $deployParams += '--parameters'
    $deployParams += "authClientSecret=$plainSecret"
}

Write-Host "Deploying $Environment to $ResourceGroup in $Location..." -ForegroundColor Cyan
& az @deployParams

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed with exit code $LASTEXITCODE"
}
else {
    Write-Host "Deployment completed successfully." -ForegroundColor Green
}
