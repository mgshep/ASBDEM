# ============================================================================
# Deploy ASBDEM DACPAC to Database
# ============================================================================
# This script publishes the ASBDEM.dacpac to a target database
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$TargetServer = "sqllaptop1\ni01",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetDatabase = "ASBDEM",
    
    [Parameter(Mandatory=$false)]
    [string]$DacpacPath = "Database\bin\Release\ASBDEM.dacpac"
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "ASBDEM DACPAC Deployment" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verify DACPAC file exists
if (-not (Test-Path $DacpacPath)) {
    Write-Host "ERROR: DACPAC file not found: $DacpacPath" -ForegroundColor Red
    exit 1
}

$fileSize = (Get-Item $DacpacPath).Length
Write-Host "DACPAC File: $DacpacPath" -ForegroundColor Green
Write-Host "File Size: $fileSize bytes" -ForegroundColor Green
Write-Host ""

Write-Host "Target Server: $TargetServer" -ForegroundColor Cyan
Write-Host "Target Database: $TargetDatabase" -ForegroundColor Cyan
Write-Host ""

Write-Host "Deploying DACPAC..." -ForegroundColor Yellow

$startTime = Get-Date

sqlpackage /Action:Publish `
    /SourceFile:$DacpacPath `
    /TargetServerName:$TargetServer `
    /TargetDatabaseName:$TargetDatabase `
    /TargetTrustServerCertificate:True `
    /p:RegisterDataTierApplication=False

if ($LASTEXITCODE -eq 0) {
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Deployment Successful!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "Database: $TargetDatabase" -ForegroundColor Green
    Write-Host "Duration: $([math]::Round($duration, 2)) seconds" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "Deployment Failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    exit 1
}
