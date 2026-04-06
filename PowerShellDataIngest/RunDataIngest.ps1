# Master PowerShell Data Ingest Script
# Orchestrates execution of all data ingestion scripts
# Purpose: Retrieves SQL Server instance properties and configuration and populates database

param(
    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = "sqllaptop1\ni01",

    [Parameter(Mandatory = $false)]
    [string]$Database = "ASBDEM"
)

# Configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SQL Server Data Ingest - Master Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target Instance: $SqlInstance" -ForegroundColor Yellow
Write-Host "Target Database: $Database" -ForegroundColor Yellow
Write-Host "Script Directory: $scriptDir" -ForegroundColor Yellow
Write-Host ""

# Track overall results
$overallSuccess = $true
$scriptsExecuted = 0
$scriptsFailed = 0

# ============================================================================
# Run GetSQLServerProperties.ps1
# ============================================================================
Write-Host "Step 1: Running GetSQLServerProperties.ps1..." -ForegroundColor Cyan
Write-Host ('-' * 50)

$propertiesScript = Join-Path $scriptDir "GetSQLServerProperties.ps1"
if (Test-Path $propertiesScript) {
    try {
        & $propertiesScript -SqlInstance $SqlInstance -Database $Database
        $scriptsExecuted++
        Write-Host "✓ GetSQLServerProperties.ps1 completed successfully" -ForegroundColor Green
    }
    catch {
        $overallSuccess = $false
        $scriptsFailed++
        Write-Host "✗ GetSQLServerProperties.ps1 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    $overallSuccess = $false
    $scriptsFailed++
    Write-Host "✗ GetSQLServerProperties.ps1 not found at: $propertiesScript" -ForegroundColor Red
}

Write-Host ""

# ============================================================================
# Run GetSQLServerConfig.ps1
# ============================================================================
Write-Host "Step 2: Running GetSQLServerConfig.ps1..." -ForegroundColor Cyan
Write-Host ('-' * 50)

$configScript = Join-Path $scriptDir "GetSQLServerConfig.ps1"
if (Test-Path $configScript) {
    try {
        & $configScript -SqlInstance $SqlInstance -Database $Database
        $scriptsExecuted++
        Write-Host "✓ GetSQLServerConfig.ps1 completed successfully" -ForegroundColor Green
    }
    catch {
        $overallSuccess = $false
        $scriptsFailed++
        Write-Host "✗ GetSQLServerConfig.ps1 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    $overallSuccess = $false
    $scriptsFailed++
    Write-Host "✗ GetSQLServerConfig.ps1 not found at: $configScript" -ForegroundColor Red
}

Write-Host ""

# ============================================================================
# Run GetSQLServerDatabases.ps1
# ============================================================================
Write-Host "Step 3: Running GetSQLServerDatabases.ps1..." -ForegroundColor Cyan
Write-Host ('-' * 50)

$databasesScript = Join-Path $scriptDir "GetSQLServerDatabases.ps1"
if (Test-Path $databasesScript) {
    try {
        & $databasesScript -SqlInstance $SqlInstance -Database $Database
        $scriptsExecuted++
        Write-Host "✓ GetSQLServerDatabases.ps1 completed successfully" -ForegroundColor Green
    }
    catch {
        $overallSuccess = $false
        $scriptsFailed++
        Write-Host "✗ GetSQLServerDatabases.ps1 failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    $overallSuccess = $false
    $scriptsFailed++
    Write-Host "✗ GetSQLServerDatabases.ps1 not found at: $databasesScript" -ForegroundColor Red
}

Write-Host ""

# ============================================================================
# Summary
# ============================================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Ingest Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Scripts Executed: $scriptsExecuted" -ForegroundColor Green
Write-Host "Scripts Failed: $scriptsFailed" -ForegroundColor $(if ($scriptsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($overallSuccess) {
    Write-Host "✓ Data ingest completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "- Verify data was inserted into core.sqlserverProperties table"
    Write-Host "- Verify data was inserted into core.sqlserverConfig table"
    Write-Host "- Verify data was inserted into core.sqlserverdatabase table"
    Write-Host "- Review any errors from individual ingest scripts"
    exit 0
}
else {
    Write-Host "✗ Data ingest completed with errors" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review the error messages above and resolve issues" -ForegroundColor Yellow
    exit 1
}
