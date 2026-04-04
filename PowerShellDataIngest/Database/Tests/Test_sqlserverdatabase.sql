-- ============================================================================
-- Test Script for core.sqlserverdatabase and log.sqlserverdatabase
-- ============================================================================
-- Purpose: Validate table structure, procedures, and audit logging

USE ASBDEM
GO

-- Test 1: Verify tables exist
PRINT 'Test 1: Verify tables exist'
PRINT '-' + REPLICATE('-', 49)

IF OBJECT_ID('[core].[sqlserverdatabase]') IS NOT NULL
    PRINT '✓ Table [core].[sqlserverdatabase] exists'
ELSE
    PRINT '✗ Table [core].[sqlserverdatabase] does NOT exist'

IF OBJECT_ID('[log].[sqlserverdatabase]') IS NOT NULL
    PRINT '✓ Table [log].[sqlserverdatabase] exists'
ELSE
    PRINT '✗ Table [log].[sqlserverdatabase] does NOT exist'

PRINT ''

-- Test 2: Verify stored procedure exists
PRINT 'Test 2: Verify stored procedure exists'
PRINT '-' + REPLICATE('-', 49)

IF OBJECT_ID('[core].[usp_UpsertServerDatabase]') IS NOT NULL
    PRINT '✓ Procedure [core].[usp_UpsertServerDatabase] exists'
ELSE
    PRINT '✗ Procedure [core].[usp_UpsertServerDatabase] does NOT exist'

PRINT ''

-- Test 3: Check current row counts
PRINT 'Test 3: Current row counts'
PRINT '-' + REPLICATE('-', 49)

DECLARE @coreCount INT = (SELECT COUNT(*)
FROM [core].[sqlserverdatabase])
DECLARE @logCount INT = (SELECT COUNT(*)
FROM [log].[sqlserverdatabase])

PRINT 'Rows in [core].[sqlserverdatabase]: ' + CAST(@coreCount AS NVARCHAR(10))
PRINT 'Rows in [log].[sqlserverdatabase]: ' + CAST(@logCount AS NVARCHAR(10))

PRINT ''

-- Test 4: View sample data from core table
PRINT 'Test 4: Sample data from [core].[sqlserverdatabase]'
PRINT '-' + REPLICATE('-', 49)

SELECT TOP 10
    databaseid,
    servername,
    databasename,
    owner,
    recoverymodel,
    status,
    isonline,
    size_mb,
    captured
FROM [core].[sqlserverdatabase]
ORDER BY databaseid DESC

PRINT ''

-- Test 5: View sample data from audit table
PRINT 'Test 5: Sample data from [log].[sqlserverdatabase]'
PRINT '-' + REPLICATE('-', 49)

SELECT TOP 20
    logid,
    servername,
    databasename,
    action,
    property,
    oldvalue,
    newvalue,
    changedby,
    changeddate
FROM [log].[sqlserverdatabase]
ORDER BY logid DESC

PRINT ''

-- Test 6: Check for duplicate registrations
PRINT 'Test 6: Check for duplicate database registrations'
PRINT '-' + REPLICATE('-', 49)

SELECT
    serverid,
    databasename,
    COUNT(*) as duplicate_count
FROM [core].[sqlserverdatabase]
GROUP BY serverid, databasename
HAVING COUNT(*) > 1

IF @@ROWCOUNT = 0
    PRINT '✓ No duplicate registrations found'

PRINT ''

-- Test 7: Show recent changes (last 24 hours)
PRINT 'Test 7: Recent changes in last 24 hours'
PRINT '-' + REPLICATE('-', 49)

SELECT
    servername,
    databasename,
    action,
    property,
    COUNT(*) as change_count,
    MAX(changeddate) as last_change
FROM [log].[sqlserverdatabase]
WHERE changeddate >= DATEADD(DAY, -1, GETDATE())
GROUP BY servername, databasename, action, property
ORDER BY last_change DESC

PRINT ''
PRINT '========================================'
PRINT 'Test execution completed'
PRINT '========================================' 
