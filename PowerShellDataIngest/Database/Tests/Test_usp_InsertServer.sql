-- =============================================
-- Test script for usp_InsertServer stored procedure
-- Tests upsert functionality in ASBDEM database
-- =============================================
USE ASBDEM;
GO

PRINT '========================================';
PRINT 'Testing usp_InsertServer Stored Procedure';
PRINT '========================================';
PRINT '';

-- Clean up test data
PRINT 'Cleaning up test data...';
DELETE FROM [core].[servers] WHERE servername LIKE 'TEST-%';
GO

-- Test 1: Insert a new server
PRINT '';
PRINT '--- Test 1: Insert New Server ---';
DECLARE @ServerID INT;
EXEC usp_InsertServer 
    @servername = 'TEST-SERVER-01',
    @servertype = 'Production',
    @serverlocation = 'US-East',
    @serverdecomdate = NULL,
    @serverid = @ServerID OUTPUT;

PRINT 'Inserted server with ID: ' + CAST(@ServerID AS VARCHAR(10));
PRINT 'Verifying insertion...';
SELECT * FROM [core].[servers] WHERE servername = 'TEST-SERVER-01';
GO

-- Test 2: Insert another new server
PRINT '';
PRINT '--- Test 2: Insert Second New Server ---';
DECLARE @ServerID2 INT;
EXEC usp_InsertServer 
    @servername = 'TEST-SERVER-02',
    @servertype = 'Development',
    @serverlocation = 'US-West',
    @serverdecomdate = NULL,
    @serverid = @ServerID2 OUTPUT;

PRINT 'Inserted server with ID: ' + CAST(@ServerID2 AS VARCHAR(10));
GO

-- Test 3: Upsert (update) existing server
PRINT '';
PRINT '--- Test 3: Upsert (Update) Existing Server ---';
PRINT 'Waiting 2 seconds to show lastdiscovery timestamp change...';
WAITFOR DELAY '00:00:02';

DECLARE @ServerID3 INT;
EXEC usp_InsertServer 
    @servername = 'TEST-SERVER-01',
    @servertype = 'Production-Updated',
    @serverlocation = 'US-East-Modified',
    @serverdecomdate = NULL,
    @serverid = @ServerID3 OUTPUT;

PRINT 'Updated server ID: ' + CAST(@ServerID3 AS VARCHAR(10));
PRINT 'Verifying update (lastdiscovery should be newer)...';
SELECT * FROM [core].[servers] WHERE servername = 'TEST-SERVER-01';
GO

-- Test 4: Test with NULL optional parameters on upsert
PRINT '';
PRINT '--- Test 4: Upsert with NULL Optional Parameters (Should Keep Existing Values) ---';
DECLARE @ServerID4 INT;
EXEC usp_InsertServer 
    @servername = 'TEST-SERVER-02',
    @servertype = NULL,
    @serverlocation = NULL,
    @serverdecomdate = NULL,
    @serverid = @ServerID4 OUTPUT;

PRINT 'Updated server ID: ' + CAST(@ServerID4 AS VARCHAR(10));
PRINT 'Verifying update (servertype and location should remain unchanged)...';
SELECT * FROM [core].[servers] WHERE servername = 'TEST-SERVER-02';
GO

-- Test 5: Insert server with minimal parameters
PRINT '';
PRINT '--- Test 5: Insert with Minimal Parameters ---';
DECLARE @ServerID5 INT;
EXEC usp_InsertServer 
    @servername = 'TEST-SERVER-03',
    @serverid = @ServerID5 OUTPUT;

PRINT 'Inserted server with ID: ' + CAST(@ServerID5 AS VARCHAR(10));
PRINT 'Verifying insertion (optional fields should be NULL)...';
SELECT * FROM [core].[servers] WHERE servername = 'TEST-SERVER-03';
GO

-- Test 6: Test error handling - NULL server name
PRINT '';
PRINT '--- Test 6: Error Handling - NULL Server Name ---';
DECLARE @ServerID6 INT;
EXEC usp_InsertServer 
    @servername = NULL,
    @serverid = @ServerID6 OUTPUT;

PRINT '';
GO

-- Summary
PRINT '';
PRINT '========================================';
PRINT 'Test Summary';
PRINT '========================================';
PRINT 'Total test servers in database:';
SELECT COUNT(*) as TestServerCount FROM [core].[servers] WHERE servername LIKE 'TEST-%';

PRINT '';
PRINT 'All test servers:';
SELECT serverid, servername, servertype, serverlocation, firstdiscovered, lastdiscovery, serverdecomdate
FROM [core].[servers] 
WHERE servername LIKE 'TEST-%'
ORDER BY servername;

PRINT '';
PRINT 'All tests completed!';
