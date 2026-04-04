-- Test with owner only (to bypass IF guard)
EXEC [core].[usp_UpsertServerDatabase]
    @serverid = 1,
    @servername = N'TestServer',
    @instancename = N'ni01',
    @databasename = N'TestDB789',
    @owner = N'sa',
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

    SELECT 'Test with owner only - Audit' as Status, COUNT(*) as [Count]
    FROM [log].[sqlserverdatabase]
    WHERE databasename = 'TestDB789'
UNION ALL
    SELECT 'Test with owner only - Core', COUNT(*)
    FROM [core].[sqlserverdatabase]
    WHERE databasename = 'TestDB789';
