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
    throw 'azureWebAppName is required in the variable group.'
}
if (Test-InvalidPipelineValue $PackagePath -or -not (Test-Path $PackagePath)) {
    throw "API package path was not found: $PackagePath"
}

Write-Host "Active subscription:"
az account show --query '{name:name, id:id}' -o json

if (Test-InvalidPipelineValue $ResourceGroup) {
    Write-Host "Looking up resource group for Web App '$WebAppName'..."
    $ResourceGroup = az webapp list --query "[?name=='$WebAppName'].resourceGroup | [0]" -o tsv
}

if (Test-InvalidPipelineValue $ResourceGroup) {
    $ResourceGroup = az resource list `
        --name $WebAppName `
        --resource-type 'Microsoft.Web/sites' `
        --query '[0].resourceGroup' -o tsv
}

if (Test-InvalidPipelineValue $ResourceGroup) {
    throw "Web App '$WebAppName' was not found in the service connection subscription. Add 'azureResourceGroup' to the variable group (Portal -> student-api-dev -> Overview -> Resource group) and verify StudentManagement-Azure uses the same subscription."
}

Write-Host "Web App: $WebAppName"
Write-Host "Resource group: $ResourceGroup"
Write-Host "Package path: $PackagePath"

$appJson = az webapp show --resource-group $ResourceGroup --name $WebAppName -o json | ConvertFrom-Json
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
    throw 'Failed to configure App Service settings.'
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
