-- Test the updated stored procedure with server types
PRINT '========================================';
PRINT 'Testing ServerType Foreign Key Relationship';
PRINT '========================================';

-- Delete test data first
DELETE FROM [core].[servers] WHERE servername LIKE 'PROD-%' OR servername LIKE 'AZURE-%';

-- Test 1: Insert a new server with SQLServer type (ID = 1)
PRINT '';
PRINT '--- Test 1: Insert with SQLServer Type ---';
DECLARE @ServerID1 INT;
EXEC usp_InsertServer 
    @servername = 'PROD-SQL-01',
    @servertypeid = 1,
    @serverlocation = 'DataCenter-A',
    @serverdecomdate = NULL,
    @serverid = @ServerID1 OUTPUT;

PRINT 'Server inserted with ID: ' + CAST(@ServerID1 AS VARCHAR(10));

-- Test 2: Insert with Azure MI type (ID = 3)
PRINT '';
PRINT '--- Test 2: Insert with Azure MI Type ---';
DECLARE @ServerID2 INT;
EXEC usp_InsertServer 
    @servername = 'AZURE-MI-01',
    @servertypeid = 3,
    @serverlocation = 'Azure-US-East',
    @serverdecomdate = NULL,
    @serverid = @ServerID2 OUTPUT;

PRINT 'Server inserted with ID: ' + CAST(@ServerID2 AS VARCHAR(10));

-- Test 3: Display all servers with their server types
PRINT '';
PRINT '--- All Servers with Server Types ---';
SELECT
    serverid,
    servername,
    servertypename AS ServerType,
    serverlocation,
    firstdiscovered,
    lastdiscovery
FROM [core].[servers] s
    LEFT JOIN [core].[servertype] st ON s.servertypeid = st.servertypeid
WHERE s.servername LIKE 'PROD-%' OR s.servername LIKE 'AZURE-%'
ORDER BY s.servername;

PRINT '';
PRINT 'Tests completed successfully!';
