[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = "sqllaptop1\ni01",

    [Parameter(Mandatory = $false)]
    [string]$Database = "ASBDEM"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Section')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $colorMap = @{
        Info    = 'White'
        Warning = 'Yellow'
        Error   = 'Red'
        Success = 'Green'
        Section = 'Cyan'
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colorMap[$Level]
}

function Add-SqlParameter {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlCommand]$Command,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [System.Data.SqlDbType]$SqlDbType,

        [Parameter(Mandatory = $false)]
        [int]$Size = 0,

        [Parameter(Mandatory = $false)]
        [System.Data.ParameterDirection]$Direction = [System.Data.ParameterDirection]::Input,

        [Parameter(Mandatory = $false)]
        $Value = $null
    )

    $parameter = $Command.Parameters.Add($Name, $SqlDbType)

    $isVariableLengthType = $SqlDbType -in @(
        [System.Data.SqlDbType]::NVarChar,
        [System.Data.SqlDbType]::VarChar,
        [System.Data.SqlDbType]::NChar,
        [System.Data.SqlDbType]::Char,
        [System.Data.SqlDbType]::VarBinary,
        [System.Data.SqlDbType]::Binary
    )

    if ($Size -gt 0) {
        $parameter.Size = $Size
    }
    elseif ($isVariableLengthType) {
        if ($Direction -ne [System.Data.ParameterDirection]::Input) {
            $parameter.Size = -1
        }
        elseif ($null -ne $Value -and $Value -isnot [System.DBNull]) {
            if ($Value -is [byte[]]) {
                $parameter.Size = $Value.Length
            }
            else {
                $parameter.Size = [Math]::Max(([string]$Value).Length, 1)
            }
        }
        else {
            $parameter.Size = -1
        }
    }

    $parameter.Direction = $Direction

    if ($Direction -ne [System.Data.ParameterDirection]::Output) {
        $parameter.Value = if ($null -eq $Value) { [System.DBNull]::Value } else { $Value }
    }

    return $parameter
}

function Get-ServerIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Items,

        [Parameter(Mandatory = $true)]
        [string]$SqlInstance
    )

    $firstItem = $Items | Select-Object -First 1
    $instanceSegment = ($SqlInstance -split ',')[0]
    $serverSegment = ($instanceSegment -split '\\')[0]
    $namedInstance = if ($instanceSegment -match '\\') { ($instanceSegment -split '\\', 2)[1] } else { $null }

    $serverName = $serverSegment
    $instanceName = $namedInstance

    if ($null -ne $firstItem) {
        if ($firstItem.PSObject.Properties.Name -contains 'ComputerName' -and -not [string]::IsNullOrWhiteSpace([string]$firstItem.ComputerName)) {
            $serverName = [string]$firstItem.ComputerName
        }

        if ($firstItem.PSObject.Properties.Name -contains 'InstanceName' -and -not [string]::IsNullOrWhiteSpace([string]$firstItem.InstanceName)) {
            $instanceName = [string]$firstItem.InstanceName
        }
    }

    if ($instanceName -eq 'MSSQLSERVER') {
        $instanceName = $null
    }

    return [pscustomobject]@{
        ServerName   = $serverName
        InstanceName = $instanceName
    }
}

function Start-ExecutionLog {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$CreatedBy
    )

    try {
        $command = $Connection.CreateCommand()
        $command.CommandType = [System.Data.CommandType]::StoredProcedure
        $command.CommandText = '[log].[usp_LogExecutionStart]'

        Add-SqlParameter -Command $command -Name '@logtype' -SqlDbType NVarChar -Size 20 -Value 'PowerShell' | Out-Null
        Add-SqlParameter -Command $command -Name '@sourcename' -SqlDbType NVarChar -Size 255 -Value 'Get-SQLServerDatabases.ps1' | Out-Null
        Add-SqlParameter -Command $command -Name '@activity' -SqlDbType NVarChar -Size 500 -Value 'Started SQL Server database inventory collection' | Out-Null
        Add-SqlParameter -Command $command -Name '@createdby' -SqlDbType NVarChar -Size 255 -Value $CreatedBy | Out-Null

        return [int]$command.ExecuteScalar()
    }
    catch {
        Write-Log "Execution start logging skipped: $($_.Exception.Message)" -Level Warning
        return $null
    }
}

function Complete-ExecutionLog {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory = $false)]
        [Nullable[int]]$LogId = $null,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Warning', 'Error')]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = $null,

        [Parameter(Mandatory = $false)]
        [string]$ErrorCode = $null,

        [Parameter(Mandatory = $false)]
        [Nullable[int]]$RecordsAffected = $null,

        [Parameter(Mandatory = $false)]
        [string]$AdditionalData = $null
    )

    if ($null -eq $LogId) {
        return
    }

    try {
        $command = $Connection.CreateCommand()
        $command.CommandType = [System.Data.CommandType]::StoredProcedure
        $command.CommandText = '[log].[usp_LogExecutionEnd]'

        Add-SqlParameter -Command $command -Name '@logid' -SqlDbType Int -Value $LogId | Out-Null
        Add-SqlParameter -Command $command -Name '@status' -SqlDbType NVarChar -Size 20 -Value $Status | Out-Null
        Add-SqlParameter -Command $command -Name '@errormessage' -SqlDbType NVarChar -Value $ErrorMessage | Out-Null
        Add-SqlParameter -Command $command -Name '@errorcode' -SqlDbType NVarChar -Size 50 -Value $ErrorCode | Out-Null
        Add-SqlParameter -Command $command -Name '@recordsaffected' -SqlDbType Int -Value $RecordsAffected | Out-Null
        Add-SqlParameter -Command $command -Name '@additionaldata' -SqlDbType NVarChar -Value $AdditionalData | Out-Null

        $command.ExecuteNonQuery() | Out-Null
    }
    catch {
        Write-Log "Execution end logging skipped: $($_.Exception.Message)" -Level Warning
    }
}

function Get-ServerId {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory = $true)]
        [string]$ServerName
    )

    $command = $Connection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.CommandText = '[core].[usp_InsertServer]'

    Add-SqlParameter -Command $command -Name '@servername' -SqlDbType NVarChar -Size 100 -Value $ServerName | Out-Null
    Add-SqlParameter -Command $command -Name '@servertypeid' -SqlDbType Int -Value $null | Out-Null
    Add-SqlParameter -Command $command -Name '@serverlocation' -SqlDbType NVarChar -Size 30 -Value $null | Out-Null
    Add-SqlParameter -Command $command -Name '@serverdecomdate' -SqlDbType DateTime -Value $null | Out-Null
    $serverIdParameter = Add-SqlParameter -Command $command -Name '@serverid' -SqlDbType Int -Direction ([System.Data.ParameterDirection]::InputOutput) -Value $null

    $command.ExecuteNonQuery() | Out-Null

    if ($serverIdParameter.Value -eq [System.DBNull]::Value -or $null -eq $serverIdParameter.Value) {
        throw "Server registration did not return a server ID for '$ServerName'."
    }

    return [int]$serverIdParameter.Value
}

function Convert-CompatibilityLevelToInt {
    param(
        [Parameter(Mandatory = $false)]
        $Value
    )

    if ($null -eq $Value -or $Value -is [System.DBNull]) {
        return $null
    }

    if ($Value -is [int]) {
        return $Value
    }

    $digits = [regex]::Match([string]$Value, '\d+')
    if ($digits.Success) {
        return [int]$digits.Value
    }

    return $null
}

function Get-NullableDateTime {
    param(
        [Parameter(Mandatory = $false)]
        $Value
    )

    if ($null -eq $Value -or $Value -is [System.DBNull]) {
        return $null
    }

    if ($Value -is [DateTime]) {
        if ($Value -le [datetime]'1900-01-01') {
            return $null
        }

        return $Value
    }

    return $null
}

function Get-DatabaseAccessedDate {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$DatabaseObject
    )

    $lastRead = if ($DatabaseObject.PSObject.Properties.Name -contains 'LastRead') { Get-NullableDateTime -Value $DatabaseObject.LastRead } else { $null }
    $lastWrite = if ($DatabaseObject.PSObject.Properties.Name -contains 'LastWrite') { Get-NullableDateTime -Value $DatabaseObject.LastWrite } else { $null }

    if ($null -ne $lastRead -and $null -ne $lastWrite) {
        if ($lastRead -ge $lastWrite) {
            return $lastRead
        }

        return $lastWrite
    }

    if ($null -ne $lastRead) {
        return $lastRead
    }

    if ($null -ne $lastWrite) {
        return $lastWrite
    }

    return $null
}

function Invoke-DatabaseUpsert {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory = $true)]
        [int]$ServerId,

        [Parameter(Mandatory = $true)]
        [string]$ServerName,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$InstanceName,

        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Owner,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Nullable[datetime]]$CreateDate = $null,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$RecoveryModel,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Nullable[int]]$CompatibilityLevel = $null,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Collation,

        [Parameter(Mandatory = $false)]
        [Nullable[bool]]$IsOnline = $null,

        [Parameter(Mandatory = $false)]
        [Nullable[bool]]$IsUserDb = $null,

        [Parameter(Mandatory = $false)]
        [Nullable[bool]]$IsWideLocaleRestricted = $null,

        [Parameter(Mandatory = $false)]
        [Nullable[double]]$SizeMb = $null,

        [Parameter(Mandatory = $false)]
        [Nullable[double]]$UnallocatedSpaceMb = $null,

        [Parameter(Mandatory = $false)]
        [Nullable[double]]$ReservedMb = $null,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [Nullable[datetime]]$Accessed = $null
    )

    $command = $Connection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.CommandText = '[core].[usp_UpsertServerDatabase]'

    Add-SqlParameter -Command $command -Name '@serverid' -SqlDbType Int -Value $ServerId | Out-Null
    Add-SqlParameter -Command $command -Name '@servername' -SqlDbType NVarChar -Size 100 -Value $ServerName | Out-Null
    Add-SqlParameter -Command $command -Name '@instancename' -SqlDbType NVarChar -Size 100 -Value $InstanceName | Out-Null
    Add-SqlParameter -Command $command -Name '@databasename' -SqlDbType NVarChar -Size 100 -Value $DatabaseName | Out-Null
    Add-SqlParameter -Command $command -Name '@owner' -SqlDbType NVarChar -Size 100 -Value $Owner | Out-Null
    Add-SqlParameter -Command $command -Name '@createdate' -SqlDbType DateTime -Value $CreateDate | Out-Null
    Add-SqlParameter -Command $command -Name '@recoverymodel' -SqlDbType NVarChar -Size 50 -Value $RecoveryModel | Out-Null
    Add-SqlParameter -Command $command -Name '@status' -SqlDbType NVarChar -Size 50 -Value $Status | Out-Null
    Add-SqlParameter -Command $command -Name '@compatibilitylevel' -SqlDbType Int -Value $CompatibilityLevel | Out-Null
    Add-SqlParameter -Command $command -Name '@collation' -SqlDbType NVarChar -Size 100 -Value $Collation | Out-Null
    Add-SqlParameter -Command $command -Name '@isonline' -SqlDbType Bit -Value $IsOnline | Out-Null
    Add-SqlParameter -Command $command -Name '@isuserdb' -SqlDbType Bit -Value $IsUserDb | Out-Null
    Add-SqlParameter -Command $command -Name '@iswidelocalerestricted' -SqlDbType Bit -Value $IsWideLocaleRestricted | Out-Null
    Add-SqlParameter -Command $command -Name '@size_mb' -SqlDbType Float -Value $SizeMb | Out-Null
    Add-SqlParameter -Command $command -Name '@unallocatedspace_mb' -SqlDbType Float -Value $UnallocatedSpaceMb | Out-Null
    Add-SqlParameter -Command $command -Name '@reserved_mb' -SqlDbType Float -Value $ReservedMb | Out-Null
    Add-SqlParameter -Command $command -Name '@accessed' -SqlDbType DateTime -Value $Accessed | Out-Null

    $command.ExecuteNonQuery() | Out-Null
}

$connection = $null
$logId = $null
$processedCount = 0
$errorCount = 0
$skippedCount = 0
$createdBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host ''
Write-Log '========================================' -Level Section
Write-Log 'Get SQL Server Databases' -Level Section
Write-Log '========================================' -Level Section
Write-Log "Source SQL Instance: $SqlInstance" -Level Info
Write-Log "Target Database: $Database" -Level Info

try {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
        throw 'The dbatools module is required. Install it with Install-Module dbatools -Scope CurrentUser.'
    }

    Import-Module dbatools -ErrorAction Stop | Out-Null

    $connectionString = "Server=$SqlInstance;Database=$Database;Integrated Security=true;TrustServerCertificate=true;Application Name=ASBDEM.GetSQLServerDatabases;"
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()

    $logId = Start-ExecutionLog -Connection $connection -CreatedBy $createdBy

    Write-Log 'Collecting database inventory with Get-DbaDatabase...' -Level Info
    $databases = @(Get-DbaDatabase -SqlInstance $SqlInstance -EnableException)

    if ($databases.Count -eq 0) {
        throw "No databases were returned for '$SqlInstance'."
    }

    $identity = Get-ServerIdentity -Items $databases -SqlInstance $SqlInstance
    $serverId = Get-ServerId -Connection $connection -ServerName $identity.ServerName

    Write-Log "Resolved server '$($identity.ServerName)' with server ID $serverId" -Level Success
    if ([string]::IsNullOrWhiteSpace($identity.InstanceName)) {
        Write-Log 'Detected default instance' -Level Info
    }
    else {
        Write-Log "Detected instance '$($identity.InstanceName)'" -Level Info
    }

    foreach ($databaseItem in $databases) {
        if ([string]::IsNullOrWhiteSpace([string]$databaseItem.Name)) {
            $skippedCount++
            Write-Log 'Skipped a database row because no database name was present.' -Level Warning
            continue
        }

        try {
            $isOnline = if ($databaseItem.PSObject.Properties.Name -contains 'IsAccessible') { [Nullable[bool]][bool]$databaseItem.IsAccessible } else { $null }
            $isUserDb = if ($databaseItem.PSObject.Properties.Name -contains 'IsSystemObject') { [Nullable[bool]](-not [bool]$databaseItem.IsSystemObject) } else { $null }
            $isWideLocaleRestricted = if ($databaseItem.PSObject.Properties.Name -contains 'IsWideLocaleRestricted') { [Nullable[bool]][bool]$databaseItem.IsWideLocaleRestricted } else { $null }
            $sizeMb = if ($databaseItem.PSObject.Properties.Name -contains 'SizeMB' -and $null -ne $databaseItem.SizeMB) { [Nullable[double]][double]$databaseItem.SizeMB } else { $null }
            $unallocatedSpaceMb = if ($databaseItem.PSObject.Properties.Name -contains 'SpaceAvailableMB' -and $null -ne $databaseItem.SpaceAvailableMB) { [Nullable[double]][double]$databaseItem.SpaceAvailableMB } elseif ($databaseItem.PSObject.Properties.Name -contains 'SpaceAvailable' -and $null -ne $databaseItem.SpaceAvailable) { [Nullable[double]]([double]$databaseItem.SpaceAvailable / 1024.0) } else { $null }
            $reservedMb = $sizeMb
            $createDate = if ($databaseItem.PSObject.Properties.Name -contains 'CreateDate') { Get-NullableDateTime -Value $databaseItem.CreateDate } else { $null }
            $compatibilityLevel = if ($databaseItem.PSObject.Properties.Name -contains 'CompatibilityLevel') { Convert-CompatibilityLevelToInt -Value $databaseItem.CompatibilityLevel } elseif ($databaseItem.PSObject.Properties.Name -contains 'Compatibility') { Convert-CompatibilityLevelToInt -Value $databaseItem.Compatibility } else { $null }
            $accessed = Get-DatabaseAccessedDate -DatabaseObject $databaseItem

            Invoke-DatabaseUpsert -Connection $connection -ServerId $serverId -ServerName $identity.ServerName -InstanceName $identity.InstanceName -DatabaseName ([string]$databaseItem.Name) -Owner $(if ($databaseItem.PSObject.Properties.Name -contains 'Owner') { [string]$databaseItem.Owner } else { $null }) -CreateDate $createDate -RecoveryModel $(if ($databaseItem.PSObject.Properties.Name -contains 'RecoveryModel') { [string]$databaseItem.RecoveryModel } else { $null }) -Status $(if ($databaseItem.PSObject.Properties.Name -contains 'Status') { [string]$databaseItem.Status } else { $null }) -CompatibilityLevel $compatibilityLevel -Collation $(if ($databaseItem.PSObject.Properties.Name -contains 'Collation') { [string]$databaseItem.Collation } else { $null }) -IsOnline $isOnline -IsUserDb $isUserDb -IsWideLocaleRestricted $isWideLocaleRestricted -SizeMb $sizeMb -UnallocatedSpaceMb $unallocatedSpaceMb -ReservedMb $reservedMb -Accessed $accessed

            $processedCount++
        }
        catch {
            $errorCount++
            Write-Log "Failed to upsert database '$($databaseItem.Name)': $($_.Exception.Message)" -Level Warning
        }
    }

    $status = if ($errorCount -gt 0) { 'Warning' } else { 'Success' }
    $additionalData = @{
        sqlInstance        = $SqlInstance
        serverName         = $identity.ServerName
        instanceName       = $identity.InstanceName
        databasesReturned  = $databases.Count
        databasesProcessed = $processedCount
        databasesSkipped   = $skippedCount
        databaseErrors     = $errorCount
    } | ConvertTo-Json -Compress

    Complete-ExecutionLog -Connection $connection -LogId $logId -Status $status -RecordsAffected $processedCount -AdditionalData $additionalData

    Write-Log "Processed $processedCount databases with $skippedCount skipped and $errorCount errors." -Level $(if ($errorCount -gt 0) { 'Warning' } else { 'Success' })

    if ($errorCount -gt 0) {
        throw "Completed with $errorCount database upsert errors."
    }
}
catch {
    $errorMessage = $_.Exception.Message

    if ($null -ne $connection -and $connection.State -eq [System.Data.ConnectionState]::Open) {
        $additionalData = @{
            sqlInstance     = $SqlInstance
            recordsAffected = $processedCount
            skipped         = $skippedCount
            databaseErrors  = $errorCount
        } | ConvertTo-Json -Compress

        Complete-ExecutionLog -Connection $connection -LogId $logId -Status Error -ErrorMessage $errorMessage -ErrorCode 'PS_ERROR' -RecordsAffected $processedCount -AdditionalData $additionalData
    }

    Write-Log $errorMessage -Level Error
    throw
}
finally {
    if ($null -ne $connection) {
        $connection.Dispose()
    }
}