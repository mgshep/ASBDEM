DECLARE @now DATETIME = GETDATE();

EXEC [core].[usp_UpsertServerDatabase]
    @serverid = 1,
    @servername = N'TestServer',
    @instancename = N'ni01',
    @databasename = N'TestDB123',
    @owner = N'sa',
    @createdate = @now,
    @recoverymodel = N'SIMPLE',
    @status = N'ONLINE',
    @compatibilitylevel = 150,
    @collation = N'SQL_Latin1_General_CP1_CI_AS',
    @isonline = 1,
    @isuserdb = 1,
    @iswidelocalerestricted = 0,
    @size_mb = 100.5,
    @unallocatedspace_mb = 10.5,
    @reserved_mb = 90.0,
    @accessed = @now;

    SELECT 'Audit Logs' as Status, COUNT(*) as [Count]
    FROM [log].[sqlserverdatabase]
    WHERE databasename = 'TestDB123'
UNION ALL
    SELECT 'Core Records', COUNT(*)
    FROM [core].[sqlserverdatabase]
    WHERE databasename = 'TestDB123';
