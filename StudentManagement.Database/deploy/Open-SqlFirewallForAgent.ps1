param(
    [string]$SqlServer,
    [string]$ResourceGroup,
    [string]$BuildId,
    [string]$ServiceConnectionName = 'StudentManagement-Azure'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-InvalidPipelineValue {
    param([string]$Value)
    return [string]::IsNullOrWhiteSpace($Value) -or $Value -match '^\$\([^)]+\)$'
}

if (Test-InvalidPipelineValue $SqlServer) {
    $SqlServer = $env:DEPLOY_SQL_SERVER
}
if (Test-InvalidPipelineValue $ResourceGroup) {
    $ResourceGroup = $env:DEPLOY_SQL_RESOURCE_GROUP
}
if (Test-InvalidPipelineValue $BuildId) {
    $BuildId = $env:DEPLOY_BUILD_ID
}
if (-not [string]::IsNullOrWhiteSpace($env:DEPLOY_SERVICE_CONNECTION)) {
    $ServiceConnectionName = $env:DEPLOY_SERVICE_CONNECTION
}

if (Test-InvalidPipelineValue $SqlServer) {
    throw 'SqlServer is required. Set sqlServer in the StudentManagement-Dev variable group.'
}
if (Test-InvalidPipelineValue $BuildId) {
    throw 'BuildId is required.'
}

if ($SqlServer -notmatch 'database\.windows\.net') {
    Write-Host 'Not Azure SQL - skipping firewall management.'
    Write-Host '##vso[task.setvariable variable=sqlFirewallManaged]false'
    exit 0
}

$agentIp = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=text').Trim()
$serverName = $SqlServer.Split('.')[0]
$ruleName = "ado-build-$BuildId"

if (Test-InvalidPipelineValue $ResourceGroup) {
    Write-Host "sqlResourceGroup not set. Looking up resource group for server '$serverName'..."

    $ResourceGroup = az sql server list --query "[?name=='$serverName'].resourceGroup | [0]" -o tsv

    if (Test-InvalidPipelineValue $ResourceGroup) {
        $ResourceGroup = az resource list `
            --name $serverName `
            --resource-type 'Microsoft.Sql/servers' `
            --query '[0].resourceGroup' -o tsv
    }
}

if (Test-InvalidPipelineValue $ResourceGroup) {
    throw @"
Could not resolve resource group for SQL server '$serverName'.
Add variable 'sqlResourceGroup' to your StudentManagement-Dev variable group (Azure Portal -> SQL server cruddev -> Overview -> Resource group),
OR grant 'Reader' on the subscription to service connection '$ServiceConnectionName'.
"@
}

Write-Host "Agent IP: $agentIp"
Write-Host "Resource group: $ResourceGroup"
Write-Host "SQL server: $serverName"
Write-Host "Firewall rule: $ruleName"

az sql server firewall-rule create `
    --resource-group $ResourceGroup `
    --server $serverName `
    --name $ruleName `
    --start-ip-address $agentIp `
    --end-ip-address $agentIp

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create SQL firewall rule on '$serverName' in RG '$ResourceGroup'. Grant 'SQL Server Contributor' to service connection '$ServiceConnectionName' (object id from service connection page), or add IP $agentIp manually: Portal -> SQL server cruddev -> Networking -> Add client IP."
}

Write-Host "##vso[task.setvariable variable=sqlFirewallManaged]true"
Write-Host "##vso[task.setvariable variable=sqlFirewallRuleName]$ruleName"
Write-Host "##vso[task.setvariable variable=sqlServerShortName]$serverName"
Write-Host "##vso[task.setvariable variable=sqlResourceGroupResolved]$ResourceGroup"
Write-Host 'Waiting 15 seconds for firewall rule to propagate...'
Start-Sleep -Seconds 15
