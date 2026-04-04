BEGIN TRY
    -- Test with owner only (to bypass IF guard)
    EXEC [core].[usp_UpsertServerDatabase]
        @serverid = 1,
        @servername = N'TestServer',
        @instancename = N'ni01',
        @databasename = N'TestDB999',
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

    SELECT 'Success' as Status;
END TRY
BEGIN CATCH
    SELECT
    'ERROR' as Status,
    ERROR_MESSAGE() as ErrorMsg,
    ERROR_LINE() as ErrorLine,
    ERROR_NUMBER() as ErrorNum,
    ERROR_SEVERITY() as Severity,
    ERROR_STATE() as State;
END CATCH
