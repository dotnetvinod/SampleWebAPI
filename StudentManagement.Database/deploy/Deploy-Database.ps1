<#
.SYNOPSIS
    Deploys Student Management database scripts to SQL Server using sqlcmd.

.PARAMETER Server
    SQL Server host (e.g. myserver.database.windows.net or localhost).

.PARAMETER Database
    Target application database name (e.g. StudentDb_Dev, StudentDb_QA).

.PARAMETER Username
    SQL authentication username. Omit when using -UseTrustedConnection.

.PARAMETER Password
    SQL authentication password. Omit when using -UseTrustedConnection.

.PARAMETER UseTrustedConnection
    Use Windows integrated authentication (local/on-prem SQL Server).

.PARAMETER TrustServerCertificate
    Trust server certificate (recommended for local dev).

.EXAMPLE
    ./Deploy-Database.ps1 -Server "localhost" -Database "StudentDb_Dev" -UseTrustedConnection -TrustServerCertificate
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [string]$Database,

    [string]$Username,
    [string]$Password,
    [switch]$UseTrustedConnection,
    [switch]$TrustServerCertificate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SqlCmdPath {
    $candidates = @(
        (Get-Command sqlcmd -ErrorAction SilentlyContinue)?.Source,
        'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE',
        'C:\Program Files\Microsoft SQL Server\160\Tools\Binn\SQLCMD.EXE',
        '/opt/mssql-tools18/bin/sqlcmd',
        '/opt/mssql-tools/bin/sqlcmd'
    ) | Where-Object { $_ -and (Test-Path $_) }

    if (-not $candidates) {
        throw 'sqlcmd was not found. Install SQL Server command-line tools or mssql-tools18.'
    }

    return $candidates[0]
}

function Invoke-SqlScript {
    param(
        [string]$ScriptPath,
        [string]$TargetDatabase,
        [hashtable]$Variables = @{}
    )

    if (-not (Test-Path $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }

    $arguments = @(
        '-S', $Server,
        '-d', $TargetDatabase,
        '-b',
        '-i', $ScriptPath
    )

    if ($UseTrustedConnection) {
        $arguments += '-E'
    }
    else {
        if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
            throw 'Username and Password are required when not using trusted connection.'
        }

        $arguments += @('-U', $Username, '-P', $Password)
    }

    if ($TrustServerCertificate) {
        $arguments += '-C'
    }

    foreach ($key in $Variables.Keys) {
        $arguments += @('-v', "$key=$($Variables[$key])")
    }

    Write-Host "Executing $ScriptPath against database '$TargetDatabase'..."
    & $sqlCmdPath @arguments

    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd failed for script '$ScriptPath' with exit code $LASTEXITCODE."
    }
}

$rootPath = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $PSScriptRoot 'deploy-manifest.json'

if (-not (Test-Path $manifestPath)) {
    throw "Deployment manifest not found: $manifestPath"
}

$manifest = Get-Content -Raw -Path $manifestPath | ConvertFrom-Json
$sqlCmdPath = Get-SqlCmdPath

Write-Host "Using sqlcmd: $sqlCmdPath"
Write-Host "Deploying database '$Database' to server '$Server'..."

foreach ($entry in ($manifest.scripts | Sort-Object order)) {
    $scriptPath = Join-Path $rootPath $entry.file
    $targetDb = if ($entry.targetDatabase -eq 'master') { 'master' } else { $Database }

    $variables = @{}
    if ($entry.targetDatabase -eq 'master') {
        $variables['DatabaseName'] = $Database
    }

    Invoke-SqlScript -ScriptPath $scriptPath -TargetDatabase $targetDb -Variables $variables
}

Write-Host "Database deployment completed successfully."
