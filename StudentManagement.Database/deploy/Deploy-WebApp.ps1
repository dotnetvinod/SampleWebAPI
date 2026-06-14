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
    throw 'azureWebAppName is required in the variable group (Portal -> App Service -> Overview -> Name).'
}
if (Test-InvalidPipelineValue $ResourceGroup) {
    throw 'azureResourceGroup is required in the variable group (Portal -> App Service -> Overview -> Resource group).'
}
if (Test-InvalidPipelineValue $PackagePath -or -not (Test-Path $PackagePath)) {
    throw "API package path was not found: $PackagePath"
}

$dllPath = Join-Path $PackagePath 'StudentManagementApi.dll'
if (-not (Test-Path $dllPath)) {
    throw "StudentManagementApi.dll was not found in $PackagePath. Build/publish artifact may be empty or wrong path."
}

$account = az account show -o json | ConvertFrom-Json
Write-Host "Pipeline subscription: $($account.name) ($($account.id))"
Write-Host "Target Web App: $WebAppName"
Write-Host "Resource group: $ResourceGroup"
Write-Host "Package path: $PackagePath"
Write-Host "Package files:"
Get-ChildItem $PackagePath | Select-Object -First 15 | ForEach-Object { Write-Host "  $($_.Name)" }

$showOutput = az webapp show --resource-group $ResourceGroup --name $WebAppName -o json 2>&1
if ($LASTEXITCODE -ne 0) {
    $details = ($showOutput | Out-String).Trim()
    if ($details -match 'AuthorizationFailed|authorization to perform action') {
        throw "PERMISSION DENIED: Grant 'Website Contributor' on resource group '$ResourceGroup' to service connection 'StudentManagement-Azure' (object id d9d290aa-7632-4181-9275-9e434e3a9d29)."
    }
    throw "Web App '$WebAppName' was not found in '$ResourceGroup'. Set azureWebAppName to the exact Name shown in Portal Overview. Details: $details"
}

$appJson = $showOutput | ConvertFrom-Json
$hostname = $appJson.defaultHostName
Write-Host "Verified Web App exists. Kind: $($appJson.kind)"
Write-Host "Default hostname: $hostname"

if (Test-InvalidPipelineValue $AspNetCoreEnvironment) {
    $AspNetCoreEnvironment = 'Development'
}

if ($appJson.kind -match 'linux') {
    Write-Host 'Linux App Service detected — setting startup command...'
    az webapp config set `
        --resource-group $ResourceGroup `
        --name $WebAppName `
        --startup-file 'dotnet StudentManagementApi.dll'
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to set Linux startup command.'
    }
}

Write-Host 'Applying App Service settings...'
az webapp config appsettings set `
    --resource-group $ResourceGroup `
    --name $WebAppName `
    --settings "ASPNETCORE_ENVIRONMENT=$AspNetCoreEnvironment"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to set ASPNETCORE_ENVIRONMENT. Grant 'Website Contributor' on '$ResourceGroup'."
}

if (-not (Test-InvalidPipelineValue $ConnectionString)) {
    az webapp config connection-string set `
        --resource-group $ResourceGroup `
        --name $WebAppName `
        --connection-string-type SQLAzure `
        --settings "DefaultConnection=$ConnectionString"

    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to set connection string on App Service.'
    }
}
else {
    Write-Warning 'apiConnectionString is empty — app will start but database calls will fail.'
}

$zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "api-deploy-$(Get-Random).zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "Creating deployment zip: $zipPath"
Push-Location $PackagePath
try {
    Compress-Archive -Path * -DestinationPath $zipPath -Force
}
finally {
    Pop-Location
}

Write-Host 'Deploying package to Azure Web App...'
az webapp deploy `
    --resource-group $ResourceGroup `
    --name $WebAppName `
    --src-path $zipPath `
    --type zip `
    --async false `
    --restart true `
    --timeout 600000

if ($LASTEXITCODE -ne 0) {
    throw 'Web App deployment failed.'
}

Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

Write-Host 'Restarting Web App...'
az webapp restart --resource-group $ResourceGroup --name $WebAppName | Out-Null

Start-Sleep -Seconds 15

$swaggerUrl = "https://$hostname/swagger/index.html"
Write-Host "Smoke test: $swaggerUrl"
try {
    $response = Invoke-WebRequest -Uri $swaggerUrl -UseBasicParsing -TimeoutSec 120 -MaximumRedirection 5
    Write-Host "Smoke test passed (HTTP $($response.StatusCode))."
}
catch {
    throw @"
Deployment finished but the app did not respond at $swaggerUrl
Error: $($_.Exception.Message)

Check in Azure Portal:
1. App Service -> Log stream (startup errors?)
2. Configuration -> General settings -> Stack must be .NET 8
3. Development Tools -> Advanced Tools -> site/wwwroot must contain StudentManagementApi.dll
"@
}

Write-Host "Deployment completed: https://$hostname/swagger"
