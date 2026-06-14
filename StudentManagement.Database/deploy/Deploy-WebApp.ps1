param(
    [string]$WebAppName,
    [string]$ResourceGroup,
    [string]$AspNetCoreEnvironment,
    [string]$ConnectionString,
    [string]$PackagePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-SqlAzureConnectionString {
    param(
        [string]$Server,
        [string]$Database,
        [string]$Username,
        [string]$Password
    )

    $dataSource = if ($Server -match ',') { $Server } else { "tcp:$Server,1433" }

    Add-Type -AssemblyName 'System.Data' | Out-Null
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder.DataSource = $dataSource
    $builder.InitialCatalog = $Database
    $builder.UserID = $Username
    $builder.Password = $Password
    $builder.Encrypt = $true
    $builder.ConnectTimeout = 30

    # Property names work on Linux agents; spaced index keys do not.
    if ($builder.PSObject.Properties.Name -contains 'TrustServerCertificate') {
        $builder.TrustServerCertificate = $false
    }

    return $builder.ConnectionString
}

function Set-WebAppConnectionString {
    param(
        [string]$ResourceGroup,
        [string]$WebAppName,
        [string]$ConnectionString
    )

    $settingsFile = Join-Path ([System.IO.Path]::GetTempPath()) "connstrings-$(Get-Random).json"
    @(
        @{
            name = 'DefaultConnection'
            value = $ConnectionString
            type = 'SQLAzure'
            slotSetting = $false
        }
    ) | ConvertTo-Json -Depth 3 | Set-Content -Path $settingsFile -Encoding utf8

    az webapp config connection-string set `
        --resource-group $ResourceGroup `
        --name $WebAppName `
        --settings "@$settingsFile"

    Remove-Item $settingsFile -Force -ErrorAction SilentlyContinue
}

function Test-InvalidPipelineValue {
    param([string]$Value)
    return [string]::IsNullOrWhiteSpace($Value) -or $Value -match '^\$\([^)]+\)$'
}

function Resolve-ConnectionString {
    param(
        [string]$ExplicitConnectionString,
        [string]$SqlServer,
        [string]$SqlDatabase,
        [string]$SqlUsername,
        [string]$SqlPassword
    )

    if (-not (Test-InvalidPipelineValue $SqlServer) `
        -and -not (Test-InvalidPipelineValue $SqlDatabase) `
        -and -not (Test-InvalidPipelineValue $SqlUsername) `
        -and -not (Test-InvalidPipelineValue $SqlPassword)) {
        Write-Host 'Building connection string from sqlServer/sqlDatabase/sqlUsername/sqlPassword.'
        Write-Host "SQL login for API: $SqlUsername"
        if ($SqlUsername -eq ($SqlServer -replace '\..*$', '')) {
            Write-Warning "sqlUsername '$SqlUsername' matches the SQL server short name. Use the SQL authentication login (e.g. sqladmin), not the server name."
        }
        return (New-SqlAzureConnectionString -Server $SqlServer -Database $SqlDatabase -Username $SqlUsername -Password $SqlPassword)
    }

    if (-not (Test-InvalidPipelineValue $ExplicitConnectionString)) {
        Write-Warning 'Using apiConnectionString from variable group. Prefer sqlServer + sqlUsername + sqlPassword so API and DB deploy use the same login.'
        return $ExplicitConnectionString
    }

    throw 'Set sqlServer, sqlDatabase, sqlUsername, and sqlPassword in the variable group (same values used for database deploy).'
}

function Resolve-WebAppName {
    param(
        [string]$Candidate,
        [string]$ResourceGroup
    )

    $inputValue = $Candidate.Trim()
    $hostnameHint = $inputValue -replace '^https?://', '' -replace '/.*$', ''

    Write-Host "Resolving Web App name from input: $inputValue"

    $direct = az webapp show --resource-group $ResourceGroup --name $inputValue -o json 2>&1
    if ($LASTEXITCODE -eq 0) {
        return @{ Name = $inputValue; Json = ($direct | ConvertFrom-Json) }
    }
    $directText = ($direct | Out-String)
    if ($directText -match 'AuthorizationFailed|authorization to perform action') {
        throw "PERMISSION DENIED: Grant 'Website Contributor' on resource group '$ResourceGroup' to service connection 'StudentManagement-Azure' (object id d9d290aa-7632-4181-9275-9e434e3a9d29)."
    }

    if ($hostnameHint -match '\.azurewebsites\.net') {
        Write-Host "Input looks like a hostname, not a resource Name. Searching resource group..."
        $appsJson = az webapp list --resource-group $ResourceGroup -o json 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($appsJson)) {
            $apps = $appsJson | ConvertFrom-Json
            foreach ($app in $apps) {
                if ($app.defaultHostName -eq $hostnameHint) {
                    Write-Host "Matched hostname to resource Name: $($app.name)"
                    return @{ Name = $app.name; Json = $app }
                }
            }
        }
    }

    $appsJson = az webapp list --resource-group $ResourceGroup -o json 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($appsJson)) {
        $apps = $appsJson | ConvertFrom-Json
        foreach ($app in $apps) {
            if ($app.name -eq $inputValue -or $app.name -eq ($hostnameHint.Split('.')[0])) {
                return @{ Name = $app.name; Json = $app }
            }
        }

        if ($apps.Count -gt 0) {
            Write-Host 'Web apps in this resource group:'
            foreach ($app in $apps) {
                Write-Host "  Name: $($app.name)  |  URL: https://$($app.defaultHostName)"
            }
        }
    }

    throw @"
Could not find Web App '$inputValue' in '$ResourceGroup'.

azureWebAppName must be the short Name from Portal Overview — NOT the full URL.

Wrong:  student-api-dev-fwfnbue5g2cje9at.centralindia-01.azurewebsites.net
Right:  student-api-dev   (copy the Name field only)

Portal -> App Service -> Overview -> Name
"@
}

if (Test-InvalidPipelineValue $WebAppName) { $WebAppName = $env:DEPLOY_WEBAPP_NAME }
if (Test-InvalidPipelineValue $ResourceGroup) { $ResourceGroup = $env:DEPLOY_WEBAPP_RESOURCE_GROUP }
if (Test-InvalidPipelineValue $AspNetCoreEnvironment) { $AspNetCoreEnvironment = $env:DEPLOY_ASPNETCORE_ENVIRONMENT }
if (Test-InvalidPipelineValue $ConnectionString) { $ConnectionString = $env:DEPLOY_CONNECTION_STRING }
if (Test-InvalidPipelineValue $PackagePath) { $PackagePath = $env:DEPLOY_PACKAGE_PATH }

$sqlServer = $env:DEPLOY_SQL_SERVER
$sqlDatabase = $env:DEPLOY_SQL_DATABASE
$sqlUsername = $env:DEPLOY_SQL_USERNAME
$sqlPassword = $env:DEPLOY_SQL_PASSWORD

$ConnectionString = Resolve-ConnectionString `
    -ExplicitConnectionString $ConnectionString `
    -SqlServer $sqlServer `
    -SqlDatabase $sqlDatabase `
    -SqlUsername $sqlUsername `
    -SqlPassword $sqlPassword

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
Write-Host "Resource group: $ResourceGroup"
Write-Host "Package path: $PackagePath"
Write-Host "Package files:"
Get-ChildItem $PackagePath | Select-Object -First 15 | ForEach-Object { Write-Host "  $($_.Name)" }

$resolved = Resolve-WebAppName -Candidate $WebAppName -ResourceGroup $ResourceGroup
$WebAppName = $resolved.Name
$appJson = $resolved.Json
$hostname = $appJson.defaultHostName

Write-Host "Target Web App Name: $WebAppName"
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
    Set-WebAppConnectionString -ResourceGroup $ResourceGroup -WebAppName $WebAppName -ConnectionString $ConnectionString

    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to set connection string on App Service.'
    }
}
else {
    Write-Warning 'Connection string is empty — app will start but database calls will fail.'
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
