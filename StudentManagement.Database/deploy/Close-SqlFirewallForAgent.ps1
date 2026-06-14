param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$ServerName,

    [Parameter(Mandatory = $true)]
    [string]$RuleName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

az sql server firewall-rule delete `
    --resource-group $ResourceGroup `
    --server $ServerName `
    --name $RuleName

Write-Host "Removed firewall rule $RuleName"
