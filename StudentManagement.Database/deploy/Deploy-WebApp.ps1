param(
    [string]$WebAppName,
    [string]$ResourceGroup,
    [string]$AspNetCoreEnvironment,
    [string]$ConnectionString,
    [string]$PackagePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-InvalidPipelineValue {
    param([string]$Value)
    return [string]::IsNullOrWhiteSpace($Value) -or $Value -match '^\$\([^)]+\)$'
}

if (Test-InvalidPipelineValue $WebAppName) { $WebAppName = $env:DEPLOY_WEBAPP_NAME }
if (Test-InvalidPipelineValue $ResourceGroup) { $ResourceGroup = $env:DEPLOY_WEBAPP_RESOURCE_GROUP }
if (Test-InvalidPipelineValue $AspNetCoreEnvironment) { $AspNetCoreEnvironment = $env:DEPLOY_ASPNETCORE_ENVIRONMENT }
if (Test-InvalidPipelineValue $ConnectionString) { $ConnectionString = $env:DEPLOY_CONNECTION_STRING }
if (Test-InvalidPipelineValue $PackagePath) { $PackagePath = $env:DEPLOY_PACKAGE_PATH }

if (Test-InvalidPipelineValue $WebAppName) {
    throw 'azureWebAppName is required in the StudentManagement-Dev variable group.'
}
if (Test-InvalidPipelineValue $PackagePath -or -not (Test-Path $PackagePath)) {
    throw "API package path was not found: $PackagePath"
}

$account = az account show -o json | ConvertFrom-Json
Write-Host "Pipeline subscription: $($account.name) ($($account.id))"
Write-Host "Target Web App: $WebAppName"

if (Test-InvalidPipelineValue $ResourceGroup) {
    Write-Host "azureResourceGroup is NOT set in the variable group. Attempting auto-lookup..."
    $ResourceGroup = az webapp list --query "[?name=='$WebAppName'].resourceGroup | [0]" -o tsv
}
else {
    Write-Host "Using azureResourceGroup from variable group: $ResourceGroup"
}

if (-not (Test-InvalidPipelineValue $ResourceGroup)) {
    Write-Host "Verifying Web App in resource group '$ResourceGroup'..."
    $showResult = az webapp show --resource-group $ResourceGroup --name $WebAppName -o json 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Web App '$WebAppName' was not found in resource group '$ResourceGroup' for this subscription."
        $ResourceGroup = $null
    }
}

if (Test-InvalidPipelineValue $ResourceGroup) {
    Write-Host "Web apps visible to the service connection in this subscription:"
    az webapp list --query "[].{name:name, resourceGroup:resourceGroup}" -o table
    throw @"
Cannot find Web App '$WebAppName' in subscription '$($account.id)'.

Fix in Azure Portal:
1. Open App Service '$WebAppName' -> Overview
2. Compare 'Subscription' to pipeline subscription above - they MUST match
3. Copy 'Resource group' and add variable 'azureResourceGroup' to StudentManagement-Dev in Azure DevOps Library

If the Web App is in a different subscription, update service connection 'StudentManagement-Azure'
to that subscription, or recreate the Web App in subscription '$($account.id)'.
"@
}

Write-Host "Web App: $WebAppName"
Write-Host "Resource group: $ResourceGroup"
Write-Host "Package path: $PackagePath"

Write-Host "Verifying Web App access in resource group '$ResourceGroup'..."
$showOutput = az webapp show --resource-group $ResourceGroup --name $WebAppName -o json 2>&1
if ($LASTEXITCODE -ne 0) {
    if ($showOutput -match 'AuthorizationFailed|authorization to perform action') {
        throw "Service connection 'StudentManagement-Azure' (object id d9d290aa-7632-4181-9275-9e434e3a9d29) cannot access Web App '$WebAppName'. Grant 'Website Contributor' or 'Contributor' on resource group '$ResourceGroup' in Azure Portal -> Access control (IAM) -> Add role assignment."
    }
    throw "Could not read Web App '$WebAppName' in '$ResourceGroup': $showOutput"
}

$appJson = $showOutput | ConvertFrom-Json
Write-Host "Verified Web App exists. Kind: $($appJson.kind)"

if (Test-InvalidPipelineValue $AspNetCoreEnvironment) {
    $AspNetCoreEnvironment = 'Development'
}

Write-Host 'Applying App Service settings...'
az webapp config appsettings set `
    --resource-group $ResourceGroup `
    --name $WebAppName `
    --settings `
        "ASPNETCORE_ENVIRONMENT=$AspNetCoreEnvironment" `
        "ConnectionStrings__DefaultConnection=$ConnectionString"

if ($LASTEXITCODE -ne 0) {
    throw 'Failed to configure App Service settings. Grant Website Contributor on the resource group to the service connection.'
}

$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "api-deploy-$(Get-Random).zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "Creating deployment zip: $zipPath"
Compress-Archive -Path (Join-Path $PackagePath '*') -DestinationPath $zipPath -Force

Write-Host 'Deploying package to Azure Web App...'
az webapp deploy `
    --resource-group $ResourceGroup `
    --name $WebAppName `
    --src-path $zipPath `
    --type zip `
    --async false

if ($LASTEXITCODE -ne 0) {
    throw 'Web App deployment failed.'
}

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Write-Host "Deployment completed: https://$WebAppName.azurewebsites.net"
