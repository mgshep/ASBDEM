# ============================================================================
# ASBDEM DACPAC Build and Deployment Script
# ============================================================================
# This script builds a DACPAC from the SQL project and can publish it
# Usage: .\BuildDACPAC.ps1 -ProjectPath "Database\InventoryDatabase.sqlproj"
# ============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ProjectPath = "Database\InventoryDatabase.sqlproj",

    [Parameter(Mandatory = $false)]
    [string]$DacpacPath = "Database\bin\Release\ASBDEM.dacpac",

    [Parameter(Mandatory = $false)]
    [ValidateSet('Build', 'Publish', 'BuildAndPublish')]
    [string]$Action = 'Build',

    [Parameter(Mandatory = $false)]
    [string]$TargetServer,

    [Parameter(Mandatory = $false)]
    [string]$TargetDatabase,

    [Parameter(Mandatory = $false)]
    [switch]$TrustServerCertificate,

    [Parameter(Mandatory = $false)]
    [string[]]$SqlPackageProperty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptDirectory = Split-Path -Parent $PSCommandPath
$repositoryRoot = Split-Path -Parent $scriptDirectory

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $color = @{
        Info    = 'White'
        Warning = 'Yellow'
        Error   = 'Red'
        Success = 'Green'
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color[$Level]
}

function Resolve-RepositoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $repositoryRoot -ChildPath $PathValue))
}

function Test-CommandAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & $Executable @Arguments 2>&1

    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = @($output)
    }
}

function Build-DacpacFromProject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath,

        [Parameter(Mandatory = $true)]
        [string]$ResolvedDacpacPath
    )

    if (-not (Test-Path -LiteralPath $ResolvedProjectPath)) {
        throw "Project file not found: $ResolvedProjectPath"
    }

    if (-not (Test-CommandAvailable -Name 'dotnet')) {
        throw 'dotnet SDK not found. Install .NET SDK 10 or later.'
    }

    $projectDirectory = Split-Path -Parent $ResolvedProjectPath
    $outputDirectory = Split-Path -Parent $ResolvedDacpacPath
    $null = New-Item -ItemType Directory -Path $outputDirectory -Force

    Write-Log "Building DACPAC from project: $ResolvedProjectPath" -Level 'Info'

    $buildResult = Invoke-ExternalCommand -Executable 'dotnet' -Arguments @('build', $ResolvedProjectPath, '-c', 'Release')
    foreach ($line in $buildResult.Output) {
        if ([string]::IsNullOrWhiteSpace("$line")) {
            continue
        }

        if ("$line" -match '^\s*0 Warning\(s\)') {
            Write-Log "$line" -Level 'Info'
        }
        elseif ("$line" -match '^\s*0 Error\(s\)') {
            Write-Log "$line" -Level 'Info'
        }
        elseif ("$line" -match 'warning') {
            Write-Log "$line" -Level 'Warning'
        }
        elseif ("$line" -match 'error') {
            Write-Log "$line" -Level 'Error'
        }
        else {
            Write-Log "$line" -Level 'Info'
        }
    }

    if ($buildResult.ExitCode -ne 0) {
        throw "Project build failed with exit code $($buildResult.ExitCode)."
    }

    $candidateDacpacs = Get-ChildItem -Path (Join-Path $projectDirectory 'bin\Release') -Filter '*.dacpac' -Recurse |
    Sort-Object LastWriteTimeUtc -Descending

    $builtDacpac = $candidateDacpacs |
    Where-Object { $_.FullName -ne $ResolvedDacpacPath } |
    Select-Object -First 1

    if ($null -eq $builtDacpac) {
        $builtDacpac = $candidateDacpacs | Select-Object -First 1
    }

    if ($null -eq $builtDacpac) {
        throw "Unable to locate built DACPAC under $(Join-Path $projectDirectory 'bin\Release')."
    }

    if ($builtDacpac.FullName -ne $ResolvedDacpacPath) {
        Copy-Item -LiteralPath $builtDacpac.FullName -Destination $ResolvedDacpacPath -Force
    }

    $fileSize = (Get-Item -LiteralPath $ResolvedDacpacPath).Length / 1MB
    Write-Log "DACPAC built successfully: $ResolvedDacpacPath ($([math]::Round($fileSize, 2)) MB)" -Level 'Success'

    return $ResolvedDacpacPath
}

function Publish-Dacpac {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedDacpacPath,

        [Parameter(Mandatory = $true)]
        [string]$Server,

        [Parameter(Mandatory = $true)]
        [string]$Database
    )

    if (-not (Test-CommandAvailable -Name 'sqlpackage')) {
        throw 'sqlpackage not found. Install the Microsoft SqlPackage dotnet tool.'
    }

    if (-not (Test-Path -LiteralPath $ResolvedDacpacPath)) {
        throw "DACPAC file not found: $ResolvedDacpacPath"
    }

    Write-Log "Publishing DACPAC to database: $Database on $Server" -Level 'Info'

    $arguments = @(
        '/Action:Publish'
        "/SourceFile:$ResolvedDacpacPath"
        "/TargetServerName:$Server"
        "/TargetDatabaseName:$Database"
        '/p:RegisterDataTierApplication=False'
    )

    if ($TrustServerCertificate.IsPresent) {
        $arguments += '/TargetTrustServerCertificate:True'
    }

    foreach ($property in ($SqlPackageProperty | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $arguments += "/p:$property"
    }

    $publishResult = Invoke-ExternalCommand -Executable 'sqlpackage' -Arguments $arguments
    foreach ($line in $publishResult.Output) {
        if ([string]::IsNullOrWhiteSpace("$line")) {
            continue
        }

        if ("$line" -match '^\s*0 Warning\(s\)') {
            Write-Log "$line" -Level 'Info'
        }
        elseif ("$line" -match '^\s*0 Error\(s\)') {
            Write-Log "$line" -Level 'Info'
        }
        elseif ("$line" -match 'warning') {
            Write-Log "$line" -Level 'Warning'
        }
        elseif ("$line" -match 'error') {
            Write-Log "$line" -Level 'Error'
        }
        else {
            Write-Log "$line" -Level 'Info'
        }
    }

    if ($publishResult.ExitCode -ne 0) {
        throw "SqlPackage Publish failed with exit code $($publishResult.ExitCode)."
    }

    Write-Log 'DACPAC published successfully' -Level 'Success'
}

$resolvedProjectPath = Resolve-RepositoryPath -PathValue $ProjectPath
$resolvedDacpacPath = Resolve-RepositoryPath -PathValue $DacpacPath

Write-Log 'Starting ASBDEM DACPAC build process' -Level 'Info'

if ($Action -in @('Build', 'BuildAndPublish')) {
    Build-DacpacFromProject -ResolvedProjectPath $resolvedProjectPath -ResolvedDacpacPath $resolvedDacpacPath | Out-Null
}

if ($Action -in @('Publish', 'BuildAndPublish')) {
    if ([string]::IsNullOrWhiteSpace($TargetServer) -or [string]::IsNullOrWhiteSpace($TargetDatabase)) {
        throw 'Publish and BuildAndPublish require -TargetServer and -TargetDatabase.'
    }

    Publish-Dacpac -ResolvedDacpacPath $resolvedDacpacPath -Server $TargetServer -Database $TargetDatabase
}

Write-Log 'ASBDEM DACPAC build process completed successfully' -Level 'Success'
