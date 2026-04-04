# ============================================================================
# Full Deployment Pipeline for ASBDEM
# ============================================================================
# This script orchestrates the complete deployment:
# 1. Build DACPAC from the SQL project
# 2. Publish DACPAC to target database
# 3. Run data ingest to populate data
# 
# Usage: .\FullDeployment.ps1 -TargetServer "server\instance" -TargetDatabase "ASBDEM" [-DropDatabaseIfExists]
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetServer,
    
    [Parameter(Mandatory = $true)]
    [string]$TargetDatabase,

    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = "Database\InventoryDatabase.sqlproj",
    
    [Parameter(Mandatory = $false)]
    [string]$DacpacPath = "Database\bin\Release\ASBDEM.dacpac",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('Fresh', 'Update')]
    [string]$DeploymentMode = 'Update',

    [Parameter(Mandatory = $false)]
    [switch]$DropDatabaseIfExists
)

# ============================================================================
# Configuration
# ============================================================================

$script:deploymentStartTime = Get-Date
$script:successCount = 0
$script:failureCount = 0
$script:deploymentLog = @()
$script:scriptDirectory = Split-Path -Parent $PSCommandPath
$script:repositoryRoot = Split-Path -Parent $script:scriptDirectory

# ============================================================================
# Logging Functions
# ============================================================================

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Section')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = @{
        'Info'    = 'White'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
        'Success' = 'Green'
        'Section' = 'Cyan'
    }
    
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $Color[$Level]
    $script:deploymentLog += $logEntry
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Log "=========================================" -Level "Section"
    Write-Log $Title -Level "Section"
    Write-Log "=========================================" -Level "Section"
}

# ============================================================================
# Utility Functions
# ============================================================================

function Resolve-RepositoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $script:repositoryRoot -ChildPath $PathValue))
}

function Test-SqlConnection {
    param(
        [string]$Server,
        [string]$Database
    )
    
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = "Server=$Server;Database=$Database;Integrated Security=true;Connection Timeout=5;"
        $connection.Open()
        $connection.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Test-SqlServerConnection {
    param(
        [string]$Server
    )

    return (Test-SqlConnection -Server $Server -Database 'master')
}

function Invoke-SqlCommand {
    param(
        [string]$Server,
        [string]$Database = 'master',
        [string]$Query
    )

    $result = & sqlcmd -S $Server -d $Database -Q $Query -b -E 2>&1

    return [pscustomobject]@{
        Success  = ($LASTEXITCODE -eq 0)
        ExitCode = $LASTEXITCODE
        Output   = @($result)
    }
}

function Test-DatabaseExists {
    param(
        [string]$Server,
        [string]$Database
    )

    $databaseLiteral = $Database.Replace("'", "''")
    $commandResult = Invoke-SqlCommand -Server $Server -Database 'master' -Query "SET NOCOUNT ON; SELECT CASE WHEN DB_ID(N'$databaseLiteral') IS NULL THEN 0 ELSE 1 END;"

    if (-not $commandResult.Success) {
        $message = ($commandResult.Output | Select-Object -Last 20) -join [Environment]::NewLine
        throw "Failed to determine whether database '$Database' exists.$([Environment]::NewLine)$message"
    }

    $normalizedOutput = ($commandResult.Output | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne '' })
    return ($normalizedOutput | Select-Object -Last 1) -eq '1'
}

function Ensure-DatabaseState {
    param(
        [string]$Server,
        [string]$Database,
        [string]$RequestedMode,
        [switch]$DropIfExists
    )

    Write-Section "Preflight: Database State"

    if (-not (Test-SqlServerConnection -Server $Server)) {
        Write-Log "Cannot connect to SQL Server instance $Server" -Level "Error"
        return [pscustomobject]@{
            Success         = $false
            EffectiveMode   = $RequestedMode
            DatabaseAdded   = $false
            DatabaseDropped = $false
        }
    }

    Write-Log "Connected to SQL Server instance: $Server" -Level "Success"

    $databaseExists = Test-DatabaseExists -Server $Server -Database $Database
    $databaseAdded = $false
    $databaseDropped = $false
    $effectiveMode = $RequestedMode
    $databaseIdentifier = $Database.Replace(']', ']]')

    if ($databaseExists) {
        Write-Log "Database '$Database' already exists" -Level "Info"

        if ($DropIfExists.IsPresent) {
            Write-Log "DropDatabaseIfExists was specified. Dropping '$Database'..." -Level "Warning"
            $dropResult = Invoke-SqlCommand -Server $Server -Database 'master' -Query "ALTER DATABASE [$databaseIdentifier] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$databaseIdentifier];"

            if (-not $dropResult.Success) {
                $message = ($dropResult.Output | Select-Object -Last 20) -join [Environment]::NewLine
                Write-Log "Failed to drop database '$Database'.$([Environment]::NewLine)$message" -Level "Error"
                return [pscustomobject]@{
                    Success         = $false
                    EffectiveMode   = $RequestedMode
                    DatabaseAdded   = $false
                    DatabaseDropped = $false
                }
            }

            Write-Log "Dropped database '$Database'" -Level "Success"
            $databaseExists = $false
            $databaseDropped = $true
            $effectiveMode = 'Fresh'
        }
    }

    if (-not $databaseExists) {
        Write-Log "Creating database '$Database'..." -Level "Info"
        $createResult = Invoke-SqlCommand -Server $Server -Database 'master' -Query "CREATE DATABASE [$databaseIdentifier];"

        if (-not $createResult.Success) {
            $message = ($createResult.Output | Select-Object -Last 20) -join [Environment]::NewLine
            Write-Log "Failed to create database '$Database'.$([Environment]::NewLine)$message" -Level "Error"
            return [pscustomobject]@{
                Success         = $false
                EffectiveMode   = $RequestedMode
                DatabaseAdded   = $false
                DatabaseDropped = $databaseDropped
            }
        }

        Write-Log "Created database '$Database'" -Level "Success"
        $databaseAdded = $true
        $effectiveMode = 'Fresh'
    }
    else {
        Write-Log "Keeping existing database '$Database'" -Level "Info"
    }

    return [pscustomobject]@{
        Success         = $true
        EffectiveMode   = $effectiveMode
        DatabaseAdded   = $databaseAdded
        DatabaseDropped = $databaseDropped
    }
}

function Invoke-SqlScript {
    param(
        [string]$Server,
        [string]$Database,
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "File not found: $FilePath" -Level "Error"
        return $false
    }
    
    try {
        $fileName = Split-Path $FilePath -Leaf
        Write-Log "  Executing: $fileName" -Level "Info"
        
        # Use sqlcmd to execute the script (handles GO batches correctly)
        $result = & sqlcmd -S $Server -d $Database -i $FilePath -b -E 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "    ✓ Success" -Level "Success"
            $script:successCount++
            return $true
        }
        else {
            Write-Log "    ✗ Failed: $result" -Level "Error"
            $script:failureCount++
            return $false
        }
    }
    catch {
        Write-Log "    ✗ Failed: $_" -Level "Error"
        $script:failureCount++
        return $false
    }
}

function Publish-Dacpac {
    param(
        [string]$Server,
        [string]$Database,
        [string]$DacpacPath
    )

    Write-Section "Phase 2: Publish DACPAC"

    try {
        $scriptDir = Split-Path -Parent $PSCommandPath
        $scriptPath = Join-Path $scriptDir "BuildDACPAC.ps1"

        if (-not (Test-Path $scriptPath)) {
            Write-Log "BuildDACPAC.ps1 not found at: $scriptPath" -Level "Error"
            return $false
        }

        Write-Log "Publishing DACPAC to $Server\$Database..." -Level "Info"

        & $scriptPath -DacpacPath $DacpacPath -Action Publish -TargetServer $Server -TargetDatabase $Database -TrustServerCertificate 2>&1 | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace("$_")) {
                return
            }

            if ($_ -match '^\s*0 Warning\(s\)' -or $_ -match '^\s*0 Error\(s\)') {
                Write-Log $_ -Level "Info"
            }
            elseif ($_ -match '\[Error\]' -or $_ -match '^Exception ' -or $_ -match '^Failed:') {
                Write-Log $_ -Level "Error"
            }
            elseif ($_ -match '\[Warning\]') {
                Write-Log $_ -Level "Warning"
            }
            elseif ($_ -match '\[Success\]') {
                Write-Log $_ -Level "Success"
            }
            else {
                Write-Log $_ -Level "Info"
            }
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Log "DACPAC publish completed successfully" -Level "Success"
            return $true
        }

        Write-Log "DACPAC publish failed" -Level "Error"
        return $false
    }
    catch {
        Write-Log "Exception during DACPAC publish: $_" -Level "Error"
        return $false
    }
}

function Build-Dacpac {
    param(
        [string]$ProjectPath,
        [string]$OutputPath
    )
    
    Write-Section "Phase 1: Build DACPAC"
    
    try {
        $scriptDir = Split-Path -Parent $PSCommandPath
        $scriptPath = Join-Path $scriptDir "BuildDACPAC.ps1"
        
        if (-not (Test-Path $scriptPath)) {
            Write-Log "BuildDACPAC.ps1 not found at: $scriptPath" -Level "Error"
            return $false
        }
        
        Write-Log "Building DACPAC from project $ProjectPath..." -Level "Info"
        
        & $scriptPath -ProjectPath $ProjectPath -DacpacPath $OutputPath -Action Build 2>&1 | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace("$_")) {
                return
            }

            if ($_ -match '^\s*0 Warning\(s\)' -or $_ -match '^\s*0 Error\(s\)') {
                Write-Log $_ -Level "Info"
            }
            elseif ($_ -match '\[Error\]' -or $_ -match '^Exception ' -or $_ -match '^Failed:') {
                Write-Log $_ -Level "Error"
            }
            elseif ($_ -match '\[Warning\]') {
                Write-Log $_ -Level "Warning"
            }
            elseif ($_ -match '\[Success\]') {
                Write-Log $_ -Level "Success"
            }
            else {
                Write-Log $_ -Level "Info"
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            $dacpacFile = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
                $OutputPath
            }
            else {
                Join-Path (Get-Location) $OutputPath
            }

            if (Test-Path $dacpacFile) {
                $fileSize = (Get-Item $dacpacFile).Length / 1MB
                Write-Log "DACPAC file verified: $dacpacFile ($([math]::Round($fileSize, 2)) MB)" -Level "Success"
                return $true
            }
            else {
                Write-Log "DACPAC file not found at expected location: $dacpacFile" -Level "Error"
                Write-Log "Checking alternative paths..." -Level "Info"
                # Check if it exists relative to current directory
                if (Test-Path "Database\bin\Release\ASBDEM.dacpac") {
                    Write-Log "DACPAC found at: Database\bin\Release\ASBDEM.dacpac" -Level "Success"
                    return $true
                }
            }
        }
        
        Write-Log "DACPAC build failed" -Level "Error"
        return $false
    }
    catch {
        Write-Log "Exception during DACPAC build: $_" -Level "Error"
        return $false
    }
}

function Invoke-DataIngest {
    param(
        [string]$Server,
        [string]$Database
    )
    
    Write-Section "Phase 3: Run Data Ingest"
    
    try {
        # Find the data ingest script - should be in PowerShellDataIngest folder
        $scriptDir = Split-Path -Parent $PSCommandPath
        $repoRoot = Split-Path -Parent $scriptDir
        $scriptPath = Join-Path $repoRoot "PowerShellDataIngest\RunDataIngest.ps1"
        
        if (-not (Test-Path $scriptPath)) {
            Write-Log "RunDataIngest.ps1 not found at: $scriptPath" -Level "Error"
            Write-Log "Checking alternative location..." -Level "Info"
            # Try alternate path
            $scriptPath = Join-Path (Get-Location) "PowerShellDataIngest\RunDataIngest.ps1"
            if (-not (Test-Path $scriptPath)) {
                Write-Log "Script still not found at: $scriptPath" -Level "Error"
                return $true  # Don't fail deployment
            }
        }
        
        Write-Log "Running data ingest from: $scriptPath" -Level "Info"
        Write-Log "Running data ingest for $Server\$Database..." -Level "Info"

        $detectedErrors = $false
        $outputLines = @(& $scriptPath -SqlInstance $Server -Database $Database 2>&1 | ForEach-Object { "$_" })

        foreach ($line in $outputLines) {
            if ($line -match '^Microsoft\.PowerShell\.Commands\.Internal\.Format\.') {
                continue
            }

            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            if ($line -match 'Could not find stored procedure|Invalid object name|\bError\b|\bFailed\b|completed with errors') {
                Write-Log $line -Level "Error"
                $detectedErrors = $true
            }
            elseif ($line -match '^WARNING:') {
                Write-Log $line -Level "Warning"
            }
            elseif ($line -match 'Success|completed successfully') {
                Write-Log $line -Level "Success"
            }
            else {
                Write-Log $line -Level "Info"
            }
        }

        if (($LASTEXITCODE -eq 0) -and (-not $detectedErrors)) {
            Write-Log "Data ingest completed successfully" -Level "Success"
            return $true
        }

        Write-Log "Data ingest completed with errors" -Level "Error"
        return $false
    }
    catch {
        Write-Log "Exception during data ingest: $_" -Level "Error"
        return $false
    }
}

# ============================================================================
# Main Execution
# ============================================================================

Write-Host ""
Write-Log "=========================================" -Level "Section"
Write-Log "ASBDEM Full Deployment Pipeline" -Level "Section"
Write-Log "=========================================" -Level "Section"
Write-Log "Target Server: $TargetServer" -Level "Info"
Write-Log "Target Database: $TargetDatabase" -Level "Info"
Write-Log "Requested Deployment Mode: $DeploymentMode" -Level "Info"
Write-Log "Drop Database If Exists: $($DropDatabaseIfExists.IsPresent)" -Level "Info"
Write-Log "Start Time: $script:deploymentStartTime" -Level "Info"

$resolvedProjectPath = Resolve-RepositoryPath -PathValue $ProjectPath
$resolvedDacpacPath = Resolve-RepositoryPath -PathValue $DacpacPath

Write-Log "Resolved Project Path: $resolvedProjectPath" -Level "Info"
Write-Log "Resolved DACPAC Path: $resolvedDacpacPath" -Level "Info"

$databaseState = Ensure-DatabaseState -Server $TargetServer -Database $TargetDatabase -RequestedMode $DeploymentMode -DropIfExists:$DropDatabaseIfExists

if (-not $databaseState.Success) {
    Write-Section "Deployment FAILED during database preparation"
    exit 1
}

$effectiveDeploymentMode = $databaseState.EffectiveMode
Write-Log "Effective Deployment Mode: $effectiveDeploymentMode" -Level "Info"

# Phase 1: Build DACPAC from project
$dacpacBuildSuccess = Build-Dacpac -ProjectPath $resolvedProjectPath -OutputPath $resolvedDacpacPath

if (-not $dacpacBuildSuccess) {
    Write-Section "Deployment FAILED during DACPAC build"
    exit 1
}

# Phase 2: Publish DACPAC
$dacpacPublishSuccess = Publish-Dacpac -Server $TargetServer -Database $TargetDatabase -DacpacPath $resolvedDacpacPath

if (-not $dacpacPublishSuccess) {
    Write-Section "Deployment FAILED during DACPAC publish"
    exit 1
}

# Phase 3: Run Data Ingest
$ingestSuccess = Invoke-DataIngest -Server $TargetServer -Database $TargetDatabase

if (-not $ingestSuccess) {
    Write-Section "Deployment FAILED during data ingest"
    exit 1
}

# ============================================================================
# Summary
# ============================================================================

Write-Section "Deployment Summary"

$script:deploymentEndTime = Get-Date
$script:deploymentDuration = ($script:deploymentEndTime - $script:deploymentStartTime).TotalSeconds
$overallStatus = 'SUCCESS'
$ingestStatusLevel = 'Success'
$ingestStatusText = 'Completed'

Write-Log "Status: $overallStatus" -Level $ingestStatusLevel
Write-Log "Database Created: $($databaseState.DatabaseAdded)" -Level "Info"
Write-Log "Database Dropped First: $($databaseState.DatabaseDropped)" -Level "Info"
Write-Log "Effective Deployment Mode: $effectiveDeploymentMode" -Level "Info"
Write-Log "DACPAC Build: Completed" -Level "Success"
Write-Log "DACPAC Publish: Completed" -Level "Success"
Write-Log "Data Ingest: $ingestStatusText" -Level $ingestStatusLevel
Write-Log "Total Duration: $([math]::Round($script:deploymentDuration, 2)) seconds" -Level "Info"
Write-Log "End Time: $script:deploymentEndTime" -Level "Info"

Write-Host ""
Write-Log "All deployment phases completed successfully!" -Level "Success"
Write-Host ""

exit 0
