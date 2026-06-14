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
if (Test-InvalidPipelineValue $ResourceGroup) {
    throw 'azureResourceGroup is required in the StudentManagement-Dev variable group (Portal -> App Service -> Overview -> Resource group).'
}
if (Test-InvalidPipelineValue $PackagePath -or -not (Test-Path $PackagePath)) {
    throw "API package path was not found: $PackagePath"
}

$account = az account show -o json | ConvertFrom-Json
Write-Host "Pipeline subscription: $($account.name) ($($account.id))"
Write-Host "Target Web App: $WebAppName"
Write-Host "Resource group: $ResourceGroup"
Write-Host "Package path: $PackagePath"

$showOutput = az webapp show --resource-group $ResourceGroup --name $WebAppName -o json 2>&1
if ($LASTEXITCODE -ne 0) {
    $details = ($showOutput | Out-String).Trim()
    if ($details -match 'AuthorizationFailed|authorization to perform action') {
        throw "PERMISSION DENIED: Grant 'Website Contributor' on resource group '$ResourceGroup' to service connection 'StudentManagement-Azure' (object id d9d290aa-7632-4181-9275-9e434e3a9d29). Portal -> rg-employee-dev -> Access control (IAM) -> Add role assignment."
    }
    throw "Web App '$WebAppName' was not found in '$ResourceGroup' for subscription '$($account.id)'. Verify subscription and resource group in Azure Portal match the pipeline, or update service connection 'StudentManagement-Azure'. Details: $details"
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
    throw "Failed to configure App Service settings. Grant 'Website Contributor' on '$ResourceGroup'."
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
