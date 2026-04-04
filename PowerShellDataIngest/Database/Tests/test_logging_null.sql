-- Simple test with NULL values instead of dates
EXEC [core].[usp_UpsertServerDatabase]
    @serverid = 1,
    @servername = N'TestServer',
    @instancename = N'ni01',
    @databasename = N'TestDBNull',
    @owner = NULL,
    @createdate = NULL,
    @recoverymodel = NULL,
    @status = NULL,
    @compatibilitylevel = NULL,
    @collation = NULL,
    @isonline = NULL,
    @isuserdb = NULL,
    @iswidelocalerestricted = NULL,
    @size_mb = NULL,
    @unallocatedspace_mb = NULL,
    @reserved_mb = NULL,
    @accessed = NULL;

    SELECT 'Test with NULLs - Audit Logs' as Status, COUNT(*) as [Count]
    FROM [log].[sqlserverdatabase]
    WHERE databasename = 'TestDBNull'
UNION ALL
    SELECT 'Test with NULLs - Core Records', COUNT(*)
    FROM [core].[sqlserverdatabase]
    WHERE databasename = 'TestDBNull';
