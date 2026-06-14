param(
    [string]$ResourceGroup,
    [string]$ServerName,
    [string]$RuleName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
    $ResourceGroup = $env:DEPLOY_SQL_RESOURCE_GROUP
}
if ([string]::IsNullOrWhiteSpace($ServerName)) {
    $ServerName = $env:DEPLOY_SQL_SERVER_SHORT_NAME
}
if ([string]::IsNullOrWhiteSpace($RuleName)) {
    $RuleName = $env:DEPLOY_SQL_FIREWALL_RULE_NAME
}

if ([string]::IsNullOrWhiteSpace($ResourceGroup) -or [string]::IsNullOrWhiteSpace($ServerName) -or [string]::IsNullOrWhiteSpace($RuleName)) {
    Write-Host 'Firewall cleanup skipped - rule details not available.'
    exit 0
}

az sql server firewall-rule delete `
    --resource-group $ResourceGroup `
    --server $ServerName `
    --name $RuleName

Write-Host "Removed firewall rule $RuleName"
