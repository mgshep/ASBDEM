[CmdletBinding(DefaultParameterSetName = 'SingleTarget')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'SingleTarget')]
    [string]$TargetServer,

    [Parameter(Mandatory = $true, ParameterSetName = 'SingleTarget')]
    [string]$TargetDatabase,

    [Parameter(Mandatory = $true, ParameterSetName = 'TargetsFile')]
    [string]$TargetsFile,

    [Parameter(Mandatory = $false)]
    [string]$DacpacPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('DeployReport', 'DriftReport', 'Both')]
    [string]$Mode = 'DeployReport',

    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = (Join-Path -Path (Get-Location) -ChildPath (Join-Path -Path 'drift-reports' -ChildPath (Get-Date -Format 'yyyyMMdd-HHmmss'))),

    [Parameter(Mandatory = $false)]
    [string]$SqlPackagePath = 'sqlpackage',

    [Parameter(Mandatory = $false)]
    [string[]]$SqlPackageProperty,

    [Parameter(Mandatory = $false)]
    [string]$TargetUser,

    [Parameter(Mandatory = $false)]
    [string]$TargetPassword,

    [Parameter(Mandatory = $false)]
    [switch]$TrustServerCertificate,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnDifferences,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $colors = @{
        Info    = 'White'
        Warning = 'Yellow'
        Error   = 'Red'
        Success = 'Green'
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colors[$Level]
}

function Resolve-SqlPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandOrPath
    )

    if (Test-Path -LiteralPath $CommandOrPath) {
        return (Resolve-Path -LiteralPath $CommandOrPath).Path
    }

    $command = Get-Command -Name $CommandOrPath -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    throw "Unable to find SqlPackage using '$CommandOrPath'. Install SqlPackage or pass -SqlPackagePath explicitly."
}

function Resolve-OptionalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [Parameter(Mandatory = $false)]
        [switch]$MustExist
    )

    if ($MustExist -and -not (Test-Path -LiteralPath $PathValue)) {
        throw "Path not found: $PathValue"
    }

    if ($MustExist) {
        return (Resolve-Path -LiteralPath $PathValue).Path
    }

    $item = Get-Item -LiteralPath $PathValue -ErrorAction SilentlyContinue
    if ($null -ne $item) {
        return $item.FullName
    }

    return [System.IO.Path]::GetFullPath($PathValue)
}

function Get-Targets {
    if ($PSCmdlet.ParameterSetName -eq 'SingleTarget') {
        return @(
            [pscustomobject]@{
                Name         = "$TargetServer-$TargetDatabase"
                ServerName   = $TargetServer
                DatabaseName = $TargetDatabase
            }
        )
    }

    $resolvedTargetsFile = Resolve-OptionalPath -PathValue $TargetsFile -MustExist
    $rawContent = Get-Content -LiteralPath $resolvedTargetsFile -Raw
    $targets = $rawContent | ConvertFrom-Json

    if ($targets -isnot [System.Collections.IEnumerable]) {
        throw 'Targets file must contain a JSON array.'
    }

    $normalizedTargets = @()
    foreach ($target in $targets) {
        if ([string]::IsNullOrWhiteSpace($target.ServerName) -or [string]::IsNullOrWhiteSpace($target.DatabaseName)) {
            throw 'Each target entry must include ServerName and DatabaseName.'
        }

        $normalizedTargets += [pscustomobject]@{
            Name         = if ([string]::IsNullOrWhiteSpace($target.Name)) { "$($target.ServerName)-$($target.DatabaseName)" } else { $target.Name }
            ServerName   = $target.ServerName
            DatabaseName = $target.DatabaseName
        }
    }

    return $normalizedTargets
}

function New-SqlPackageArguments {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('DeployReport', 'DriftReport')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Target,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$ResolvedDacpacPath
    )

    $args = @(
        "/Action:$Action"
        "/TargetServerName:$($Target.ServerName)"
        "/TargetDatabaseName:$($Target.DatabaseName)"
        "/OutputPath:$OutputPath"
    )

    if ($Action -eq 'DeployReport') {
        if ([string]::IsNullOrWhiteSpace($ResolvedDacpacPath)) {
            throw 'DeployReport requires -DacpacPath.'
        }

        $args += "/SourceFile:$ResolvedDacpacPath"
    }

    if ($TrustServerCertificate.IsPresent) {
        $args += '/TargetTrustServerCertificate:True'
    }

    if (-not [string]::IsNullOrWhiteSpace($TargetUser)) {
        $args += "/TargetUser:$TargetUser"
    }

    if (-not [string]::IsNullOrWhiteSpace($TargetPassword)) {
        $args += "/TargetPassword:$TargetPassword"
    }

    foreach ($property in ($SqlPackageProperty | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $args += "/p:$property"
    }

    return $args
}

function Invoke-SqlPackageAction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & $Executable @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = @($output)
    }
}

function Get-XmlNodeList {
    param(
        [Parameter(Mandatory = $true)]
        [xml]$XmlDocument,

        [Parameter(Mandatory = $true)]
        [string]$LocalName
    )

    return @($XmlDocument.SelectNodes(("//*[local-name()='{0}']" -f $LocalName)))
}

function Get-AttributeValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$Node,

        [Parameter(Mandatory = $true)]
        [string]$AttributeName
    )

    if ($null -eq $Node.Attributes) {
        return $null
    }

    $attribute = $Node.Attributes[$AttributeName]
    if ($null -eq $attribute) {
        return $null
    }

    return $attribute.Value
}

function Get-ReportSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('DeployReport', 'DriftReport')]
        [string]$Action
    )

    [xml]$reportXml = Get-Content -LiteralPath $ReportPath -Raw

    $operationNodes = Get-XmlNodeList -XmlDocument $reportXml -LocalName 'Operation'
    $operationNames = @(
        foreach ($node in $operationNodes) {
            $name = Get-AttributeValue -Node $node -AttributeName 'Name'
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $name
            }
        }
    )

    $changedObjects = @(
        foreach ($node in (Get-XmlNodeList -XmlDocument $reportXml -LocalName 'Item')) {
            $value = Get-AttributeValue -Node $node -AttributeName 'Value'
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $value
            }
        }
    )

    $alerts = @(
        foreach ($node in (Get-XmlNodeList -XmlDocument $reportXml -LocalName 'Alert')) {
            $name = Get-AttributeValue -Node $node -AttributeName 'Name'
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $name
            }
        }
    )

    return [pscustomobject]@{
        Action          = $Action
        ReportPath      = $ReportPath
        DifferenceCount = $operationNames.Count
        HasDifferences  = ($operationNames.Count -gt 0)
        Operations      = $operationNames
        ChangedObjects  = ($changedObjects | Select-Object -Unique)
        Alerts          = $alerts
    }
}

function Write-ResultSummary {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Result
    )

    $status = if ($Result.HasDifferences) { 'Differences detected' } else { 'No differences detected' }
    $level = if ($Result.HasDifferences) { 'Warning' } else { 'Success' }
    Write-Log "$($Result.TargetName) [$($Result.Action)]: $status" -Level $level
    Write-Log "  Report: $($Result.ReportPath)" -Level 'Info'

    if ($Result.ChangedObjects.Count -gt 0) {
        $preview = ($Result.ChangedObjects | Select-Object -First 10) -join ', '
        Write-Log "  Objects: $preview" -Level 'Info'
    }

    if ($Result.Alerts.Count -gt 0) {
        $alertPreview = ($Result.Alerts | Select-Object -First 5) -join ', '
        Write-Log "  Alerts: $alertPreview" -Level 'Warning'
    }
}

$resolvedSqlPackage = Resolve-SqlPackage -CommandOrPath $SqlPackagePath
$resolvedOutputDirectory = Resolve-OptionalPath -PathValue $OutputDirectory
$null = New-Item -ItemType Directory -Path $resolvedOutputDirectory -Force

$resolvedDacpacPath = $null
if ($Mode -in @('DeployReport', 'Both')) {
    if ([string]::IsNullOrWhiteSpace($DacpacPath)) {
        throw 'Mode DeployReport or Both requires -DacpacPath.'
    }

    $resolvedDacpacPath = Resolve-OptionalPath -PathValue $DacpacPath -MustExist
}

$targets = Get-Targets
$results = @()

foreach ($target in $targets) {
    Write-Log "Processing $($target.Name) ($($target.ServerName)/$($target.DatabaseName))" -Level 'Info'

    $actions = switch ($Mode) {
        'DeployReport' { @('DeployReport') }
        'DriftReport' { @('DriftReport') }
        'Both' { @('DeployReport', 'DriftReport') }
    }

    foreach ($action in $actions) {
        $fileName = '{0}-{1}-{2}.xml' -f $target.Name, $target.DatabaseName, $action
        $safeFileName = ($fileName -replace '[^A-Za-z0-9._-]', '_')
        $reportPath = Join-Path -Path $resolvedOutputDirectory -ChildPath $safeFileName

        $arguments = New-SqlPackageArguments -Action $action -Target $target -OutputPath $reportPath -ResolvedDacpacPath $resolvedDacpacPath
        $commandResult = Invoke-SqlPackageAction -Executable $resolvedSqlPackage -Arguments $arguments

        if ($commandResult.ExitCode -ne 0) {
            $message = ($commandResult.Output | Select-Object -Last 20) -join [Environment]::NewLine
            throw "SqlPackage $action failed for $($target.Name) with exit code $($commandResult.ExitCode).$([Environment]::NewLine)$message"
        }

        if (-not (Test-Path -LiteralPath $reportPath)) {
            throw "SqlPackage $action succeeded but did not create report: $reportPath"
        }

        $summary = Get-ReportSummary -ReportPath $reportPath -Action $action
        $result = [pscustomobject]@{
            TargetName      = $target.Name
            ServerName      = $target.ServerName
            DatabaseName    = $target.DatabaseName
            Action          = $summary.Action
            ReportPath      = $summary.ReportPath
            HasDifferences  = $summary.HasDifferences
            DifferenceCount = $summary.DifferenceCount
            Operations      = $summary.Operations
            ChangedObjects  = $summary.ChangedObjects
            Alerts          = $summary.Alerts
        }

        $results += $result
        Write-ResultSummary -Result $result
    }
}

$summaryPath = Join-Path -Path $resolvedOutputDirectory -ChildPath 'summary.json'
$results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Log "Summary written to $summaryPath" -Level 'Info'

$hasDifferences = ($results | Where-Object { $_.HasDifferences }).Count -gt 0
if ($FailOnDifferences.IsPresent -and $hasDifferences) {
    Write-Log 'Differences detected and -FailOnDifferences was specified.' -Level 'Error'
    exit 2
}

if ($PassThru.IsPresent) {
    $results
}