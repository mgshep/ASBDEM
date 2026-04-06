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

function Get-PropertyName {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$InputObject
    )

    foreach ($candidate in 'Property', 'Name', 'DisplayName') {
        if ($InputObject.PSObject.Properties.Name -contains $candidate) {
            $value = $InputObject.$candidate
            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                return [string]$value
            }
        }
    }

    return $null
}

function Convert-PropertyValueToString {
    param(
        [Parameter(Mandatory = $false)]
        $Value
    )

    if ($null -eq $Value -or $Value -is [System.DBNull]) {
        return $null
    }

    if ($Value -is [DateTime]) {
        return $Value.ToString('o')
    }

    if ($Value -is [bool]) {
        return $Value.ToString()
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return ($Value | ConvertTo-Json -Compress -Depth 5)
    }

    return [string]$Value
}

function Get-PropertyType {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$InputObject,

        [Parameter(Mandatory = $false)]
        $PropertyValue
    )

    foreach ($candidate in 'PropertyType', 'Type', 'Category') {
        if ($InputObject.PSObject.Properties.Name -contains $candidate) {
            $value = $InputObject.$candidate
            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                return [string]$value
            }
        }
    }

    if ($null -ne $PropertyValue -and $PropertyValue -isnot [System.DBNull]) {
        return $PropertyValue.GetType().Name
    }

    return 'Information'
}

function Get-ServerIdentity {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Properties,

        [Parameter(Mandatory = $true)]
        [string]$SqlInstance
    )

    $firstProperty = $Properties | Select-Object -First 1
    $instanceSegment = ($SqlInstance -split ',')[0]
    $serverSegment = ($instanceSegment -split '\\')[0]
    $namedInstance = if ($instanceSegment -match '\\') { ($instanceSegment -split '\\', 2)[1] } else { $null }

    $serverName = $serverSegment
    $instanceName = $namedInstance

    if ($null -ne $firstProperty) {
        if ($firstProperty.PSObject.Properties.Name -contains 'ComputerName' -and -not [string]::IsNullOrWhiteSpace([string]$firstProperty.ComputerName)) {
            $serverName = [string]$firstProperty.ComputerName
        }

        if ($firstProperty.PSObject.Properties.Name -contains 'InstanceName' -and -not [string]::IsNullOrWhiteSpace([string]$firstProperty.InstanceName)) {
            $instanceName = [string]$firstProperty.InstanceName
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
        Add-SqlParameter -Command $command -Name '@sourcename' -SqlDbType NVarChar -Size 255 -Value 'Get-SQLServerProperties.ps1' | Out-Null
        Add-SqlParameter -Command $command -Name '@activity' -SqlDbType NVarChar -Size 500 -Value 'Started SQL Server property collection' | Out-Null
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

function Invoke-PropertyUpsert {
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
        [string]$PropertyName,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$PropertyValue,

        [Parameter(Mandatory = $true)]
        [string]$PropertyType
    )

    $command = $Connection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.CommandText = '[core].[usp_UpsertServerProperty]'

    Add-SqlParameter -Command $command -Name '@serverid' -SqlDbType Int -Value $ServerId | Out-Null
    Add-SqlParameter -Command $command -Name '@servername' -SqlDbType NVarChar -Size 100 -Value $ServerName | Out-Null
    Add-SqlParameter -Command $command -Name '@instancename' -SqlDbType NVarChar -Size 100 -Value $InstanceName | Out-Null
    Add-SqlParameter -Command $command -Name '@propertyname' -SqlDbType NVarChar -Size 200 -Value $PropertyName | Out-Null
    Add-SqlParameter -Command $command -Name '@propertyvalue' -SqlDbType NVarChar -Value $PropertyValue | Out-Null
    Add-SqlParameter -Command $command -Name '@propertytype' -SqlDbType NVarChar -Size 50 -Value $PropertyType | Out-Null
    $successParameter = Add-SqlParameter -Command $command -Name '@success' -SqlDbType Bit -Direction ([System.Data.ParameterDirection]::Output)
    $errorParameter = Add-SqlParameter -Command $command -Name '@errormessage' -SqlDbType NVarChar -Direction ([System.Data.ParameterDirection]::Output)

    $command.ExecuteNonQuery() | Out-Null

    $errorMessage = if ($errorParameter.Value -eq [System.DBNull]::Value) { $null } else { [string]$errorParameter.Value }
    $successValue = if ($successParameter.Value -eq [System.DBNull]::Value -or $null -eq $successParameter.Value) {
        $null
    }
    else {
        [bool]$successParameter.Value
    }

    return [pscustomobject]@{
        Success      = if (-not [string]::IsNullOrWhiteSpace($errorMessage)) { $false } elseif ($null -ne $successValue) { $successValue } else { $true }
        ErrorMessage = $errorMessage
    }
}

$connection = $null
$logId = $null
$insertedCount = 0
$errorCount = 0
$skippedCount = 0
$createdBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host ''
Write-Log '========================================' -Level Section
Write-Log 'Get SQL Server Properties' -Level Section
Write-Log '========================================' -Level Section
Write-Log "Source SQL Instance: $SqlInstance" -Level Info
Write-Log "Target Database: $Database" -Level Info

try {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
        throw 'The dbatools module is required. Install it with Install-Module dbatools -Scope CurrentUser.'
    }

    Import-Module dbatools -ErrorAction Stop | Out-Null

    $connectionString = "Server=$SqlInstance;Database=$Database;Integrated Security=true;TrustServerCertificate=true;Application Name=ASBDEM.GetSQLServerProperties;"
    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()

    $logId = Start-ExecutionLog -Connection $connection -CreatedBy $createdBy

    Write-Log 'Collecting instance properties with Get-DbaInstanceProperty...' -Level Info
    $properties = @(Get-DbaInstanceProperty -SqlInstance $SqlInstance -EnableException)

    if ($properties.Count -eq 0) {
        throw "No instance properties were returned for '$SqlInstance'."
    }

    $identity = Get-ServerIdentity -Properties $properties -SqlInstance $SqlInstance
    $serverId = Get-ServerId -Connection $connection -ServerName $identity.ServerName

    Write-Log "Resolved server '$($identity.ServerName)' with server ID $serverId" -Level Success
    if ([string]::IsNullOrWhiteSpace($identity.InstanceName)) {
        Write-Log 'Detected default instance' -Level Info
    }
    else {
        Write-Log "Detected instance '$($identity.InstanceName)'" -Level Info
    }

    foreach ($property in $properties) {
        $propertyName = Get-PropertyName -InputObject $property
        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            $skippedCount++
            Write-Log 'Skipped a property row because no property name was present.' -Level Warning
            continue
        }

        $rawValue = if ($property.PSObject.Properties.Name -contains 'Value') { $property.Value } else { $null }
        $propertyValue = Convert-PropertyValueToString -Value $rawValue
        $propertyType = Get-PropertyType -InputObject $property -PropertyValue $rawValue

        $result = Invoke-PropertyUpsert -Connection $connection -ServerId $serverId -ServerName $identity.ServerName -InstanceName $identity.InstanceName -PropertyName $propertyName -PropertyValue $propertyValue -PropertyType $propertyType

        if ($result.Success) {
            $insertedCount++
        }
        else {
            $errorCount++
            Write-Log "Failed to upsert property '$propertyName': $($result.ErrorMessage)" -Level Warning
        }
    }

    $status = if ($errorCount -gt 0) { 'Warning' } else { 'Success' }
    $additionalData = @{
        sqlInstance         = $SqlInstance
        serverName          = $identity.ServerName
        instanceName        = $identity.InstanceName
        propertiesReturned  = $properties.Count
        propertiesProcessed = $insertedCount
        propertiesSkipped   = $skippedCount
        propertyErrors      = $errorCount
    } | ConvertTo-Json -Compress

    Complete-ExecutionLog -Connection $connection -LogId $logId -Status $status -RecordsAffected $insertedCount -AdditionalData $additionalData

    Write-Log "Processed $insertedCount properties with $skippedCount skipped and $errorCount errors." -Level $(if ($errorCount -gt 0) { 'Warning' } else { 'Success' })

    if ($errorCount -gt 0) {
        throw "Completed with $errorCount property upsert errors."
    }
}
catch {
    $errorMessage = $_.Exception.Message

    if ($null -ne $connection -and $connection.State -eq [System.Data.ConnectionState]::Open) {
        $additionalData = @{
            sqlInstance     = $SqlInstance
            recordsAffected = $insertedCount
            skipped         = $skippedCount
            propertyErrors  = $errorCount
        } | ConvertTo-Json -Compress

        Complete-ExecutionLog -Connection $connection -LogId $logId -Status Error -ErrorMessage $errorMessage -ErrorCode 'PS_ERROR' -RecordsAffected $insertedCount -AdditionalData $additionalData
    }

    Write-Log $errorMessage -Level Error
    throw
}
finally {
    if ($null -ne $connection) {
        $connection.Dispose()
    }
}