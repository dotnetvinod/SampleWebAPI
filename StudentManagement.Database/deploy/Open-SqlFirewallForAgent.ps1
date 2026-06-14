param(
    [string]$SqlServer,
    [string]$ResourceGroup,
    [string]$BuildId,
    [string]$ServiceConnectionName = 'StudentManagement-Azure'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SqlServer)) {
    $SqlServer = $env:DEPLOY_SQL_SERVER
}
if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
    $ResourceGroup = $env:DEPLOY_SQL_RESOURCE_GROUP
}
if ([string]::IsNullOrWhiteSpace($BuildId)) {
    $BuildId = $env:DEPLOY_BUILD_ID
}
if (-not [string]::IsNullOrWhiteSpace($env:DEPLOY_SERVICE_CONNECTION)) {
    $ServiceConnectionName = $env:DEPLOY_SERVICE_CONNECTION
}

if ([string]::IsNullOrWhiteSpace($SqlServer)) {
    throw 'SqlServer is required. Set sqlServer in the variable group.'
}
if ([string]::IsNullOrWhiteSpace($BuildId)) {
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

if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
    Write-Host "sqlResourceGroup not set. Looking up resource group for server '$serverName'..."
    $ResourceGroup = az sql server list --query "[?name=='$serverName'].resourceGroup | [0]" -o tsv
}

if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
    throw "Could not resolve resource group for SQL server '$serverName'. Add sqlResourceGroup to the variable group or grant Reader on the subscription."
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
    throw "Failed to create SQL firewall rule. Grant 'SQL Server Contributor' on server '$serverName' to service connection '$ServiceConnectionName', or add IP $agentIp manually in Azure Portal."
}

Write-Host "##vso[task.setvariable variable=sqlFirewallManaged]true"
Write-Host "##vso[task.setvariable variable=sqlFirewallRuleName]$ruleName"
Write-Host "##vso[task.setvariable variable=sqlServerShortName]$serverName"
Write-Host "##vso[task.setvariable variable=sqlResourceGroupResolved]$ResourceGroup"
Write-Host 'Waiting 15 seconds for firewall rule to propagate...'
Start-Sleep -Seconds 15
