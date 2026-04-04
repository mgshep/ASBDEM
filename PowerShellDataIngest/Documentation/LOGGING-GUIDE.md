# Execution Logging Guide

## Overview
The ASBDEM database now includes a comprehensive logging system to track execution of both PowerShell scripts and SQL stored procedures. All logs are stored in the `log.executionlog` table in the `log` schema.

## Table Structure

**Table: `log.executionlog`**
- `logid` - Unique identifier
- `logtype` - 'SQL' or 'PowerShell'
- `sourcename` - Procedure/script name
- `activity` - Description of activity
- `status` - 'Success', 'Warning', or 'Error'
- `errormessage` - Error message if applicable
- `errorcode` - Error code if applicable
- `recordsaffected` - Number of records affected
- `executiontime` - Execution time in milliseconds
- `starttime` - When execution started
- `endtime` - When execution ended
- `createdby` - User or script that logged
- `additionaldata` - Additional context (JSON recommended)

## Available Stored Procedures

### 1. `usp_LogExecutionStart`
Logs the start of an operation and returns a log ID.

**Usage:**
```sql
EXEC [log].[usp_LogExecutionStart]
    @logtype = 'PowerShell',
    @sourcename = 'GetSQLServerProperties.ps1',
    @activity = 'Started server properties collection',
    @createdby = 'DOMAIN\Username'
```

**Returns:** `logid` (INT) - Use this ID to end the log entry

### 2. `usp_LogExecutionEnd`
Updates a log entry with completion status, errors, and execution time.

**Usage:**
```sql
EXEC [log].[usp_LogExecutionEnd]
    @logid = 1,
    @status = 'Success',
    @errormessage = NULL,
    @errorcode = NULL,
    @recordsaffected = 74,
    @additionaldata = '{"serverCount":1,"propertiesCollected":74}'
```

### 3. `usp_LogActivity`
Logs a single activity without start/end tracking (for quick single-event logging).

**Usage:**
```sql
EXEC [log].[usp_LogActivity]
    @logtype = 'PowerShell',
    @sourcename = 'GetSQLServerProperties.ps1',
    @activity = 'Skipped property with null name',
    @status = 'Warning',
    @recordsaffected = 1,
    @createdby = 'DOMAIN\Username'
```

## PowerShell Integration Example

```powershell
# Example: Using logging in GetSQLServerProperties.ps1

$sqlInstance = "sqllaptop1\ni01"
$database = "ASBDEM"
$logtype = "PowerShell"
$sourceName = "GetSQLServerProperties.ps1"
$createdBy = "$env:USERDOMAIN\$env:USERNAME"

# Create SQL connection
$connectionString = "Server=$sqlInstance;Database=$database;Integrated Security=true;"
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection
$sqlConnection.ConnectionString = $connectionString
$sqlConnection.Open()

try {
    # Log execution start
    $logStartCmd = New-Object System.Data.SqlClient.SqlCommand
    $logStartCmd.Connection = $sqlConnection
    $logStartCmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $logStartCmd.CommandText = "[log].[usp_LogExecutionStart]"
    
    $logStartCmd.Parameters.AddWithValue("@logtype", $logtype) | Out-Null
    $logStartCmd.Parameters.AddWithValue("@sourcename", $sourceName) | Out-Null
    $logStartCmd.Parameters.AddWithValue("@activity", "Started server properties collection") | Out-Null
    $logStartCmd.Parameters.AddWithValue("@createdby", $createdBy) | Out-Null
    
    $logid = $logStartCmd.ExecuteScalar()
    Write-Host "Logging started with ID: $logid" -ForegroundColor Green
    
    # ... your processing code here ...
    
    $insertCount = 0
    $errorCount = 0
    
    # Log execution end with success
    $logEndCmd = New-Object System.Data.SqlClient.SqlCommand
    $logEndCmd.Connection = $sqlConnection
    $logEndCmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $logEndCmd.CommandText = "[log].[usp_LogExecutionEnd]"
    
    $logEndCmd.Parameters.AddWithValue("@logid", $logid) | Out-Null
    $logEndCmd.Parameters.AddWithValue("@status", "Success") | Out-Null
    $logEndCmd.Parameters.AddWithValue("@errormessage", [System.DBNull]::Value) | Out-Null
    $logEndCmd.Parameters.AddWithValue("@errorcode", [System.DBNull]::Value) | Out-Null
    $logEndCmd.Parameters.AddWithValue("@recordsaffected", $insertCount) | Out-Null
    
    $additionalData = @{
        "insertedRecords" = $insertCount
        "errors" = $errorCount
        "server" = $sqlInstance
    } | ConvertTo-Json
    
    $logEndCmd.Parameters.AddWithValue("@additionaldata", $additionalData) | Out-Null
    $logEndCmd.ExecuteNonQuery() | Out-Null
    
    Write-Host "Execution logged successfully" -ForegroundColor Green
}
catch {
    # Log execution end with error
    $logEndCmd = New-Object System.Data.SqlClient.SqlCommand
    $logEndCmd.Connection = $sqlConnection
    $logEndCmd.CommandType = [System.Data.CommandType]::StoredProcedure
    $logEndCmd.CommandText = "[log].[usp_LogExecutionEnd]"
    
    $logEndCmd.Parameters.AddWithValue("@logid", $logid) | Out-Null
    $logEndCmd.Parameters.AddWithValue("@status", "Error") | Out-Null
    $logEndCmd.Parameters.AddWithValue("@errormessage", $_.Exception.Message) | Out-Null
    $logEndCmd.Parameters.AddWithValue("@errorcode", "PS_ERROR") | Out-Null
    $logEndCmd.Parameters.AddWithValue("@recordsaffected", [System.DBNull]::Value) | Out-Null
    $logEndCmd.ExecuteNonQuery() | Out-Null
    
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    $sqlConnection.Close()
}
```

## Querying Logs

### View All Logs
```sql
SELECT * FROM [log].[vw_ExecutionLog]
ORDER BY starttime DESC
```

### View Recent Errors
```sql
SELECT 
    logid, 
    sourcename, 
    activity, 
    status, 
    errormessage, 
    starttime
FROM [log].[vw_ExecutionLog]
WHERE status = 'Error'
    AND starttime >= DATEADD(DAY, -1, GETDATE())
ORDER BY starttime DESC
```

### View PowerShell Script Execution Summary
```sql
SELECT 
    sourcename,
    COUNT(*) AS execution_count,
    SUM(CASE WHEN status = 'Success' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN status = 'Error' THEN 1 ELSE 0 END) AS errors,
    AVG(executiontime) AS avg_execution_time_ms
FROM [log].[executionlog]
WHERE logtype = 'PowerShell'
    AND starttime >= DATEADD(DAY, -7, GETDATE())
GROUP BY sourcename
ORDER BY execution_count DESC
```

### View Performance Statistics
```sql
SELECT 
    sourcename,
    MIN(executiontime) AS min_time_ms,
    MAX(executiontime) AS max_time_ms,
    AVG(executiontime) AS avg_time_ms,
    SUM(recordsaffected) AS total_records_processed
FROM [log].[executionlog]
WHERE executiontime IS NOT NULL
GROUP BY sourcename
ORDER BY avg_time_ms DESC
```

## Permissions
The `PowerShellUser` role has been granted:
- EXECUTE on all logging procedures
- SELECT on the executionlog table
- SELECT on the vw_ExecutionLog view

## Best Practices

1. **Always log start and end** - Use both `usp_LogExecutionStart` and `usp_LogExecutionEnd` for comprehensive tracking
2. **Include context data** - Use `additionaldata` parameter with JSON for rich context
3. **Capture error details** - Log error messages and codes when operations fail
4. **Track record counts** - Use `recordsaffected` to monitor data processing volume
5. **Set appropriate status** - Use 'Success', 'Warning', or 'Error' consistently
6. **Review logs regularly** - Set up alerts for failed executions using the error status logs

## Example: Error Logging Pattern
```powershell
try {
    # Operation code
    $result = Invoke-Operation
}
catch {
    # Log specific error
    $logErrorCmd.Parameters["@errormessage"].Value = $_.Exception.Message
    $logErrorCmd.Parameters["@errorcode"].Value = $_.ErrorDetails.Message
    $logErrorCmd.ExecuteNonQuery() | Out-Null
}
```
