-- Test 1: All NULL parameters
BEGIN TRY
    PRINT 'Test 1: All parameters NULL';
    EXEC [core].[usp_UpsertServerDatabase]
        @serverid = 1,
        @servername = N'Test1',
        @instancename = N'ni01',
        @databasename = N'Test1_AllNull',
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
    PRINT '✓ Test 1 Success';
END TRY
BEGIN CATCH
    PRINT '✗ Test 1 Failed: ' + ERROR_MESSAGE();
END CATCH

-- Test 2: Only owner parameter set
BEGIN TRY
    PRINT '';
    PRINT 'Test 2: Only owner set';
    EXEC [core].[usp_UpsertServerDatabase]
        @serverid = 2,
        @servername = N'Test2',
        @instancename = N'ni01',
        @databasename = N'Test2_OnlyOwner',
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
    PRINT '✓ Test 2 Success';
END TRY
BEGIN CATCH
    PRINT '✗ Test 2 Failed: ' + ERROR_MESSAGE();
END CATCH

-- Test 3: Only size_mb parameter set
BEGIN TRY
    PRINT '';
    PRINT 'Test 3: Only size_mb set';
    EXEC [core].[usp_UpsertServerDatabase]
        @serverid = 3,
        @servername = N'Test3',
        @instancename = N'ni01',
        @databasename = N'Test3_OnlySize',
        @owner = NULL,
        @createdate = NULL,
        @recoverymodel = NULL,
        @status = NULL,
        @compatibilitylevel = NULL,
        @collation = NULL,
        @isonline = NULL,
        @isuserdb = NULL,
        @iswidelocalerestricted = NULL,
        @size_mb = 100.5,
        @unallocatedspace_mb = NULL,
        @reserved_mb = NULL,
        @accessed = NULL;
    PRINT '✓ Test 3 Success';
END TRY
BEGIN CATCH
    PRINT '✗ Test 3 Failed: ' + ERROR_MESSAGE();
END CATCH

-- Test 4: Only isonline parameter set
BEGIN TRY
    PRINT '';
    PRINT 'Test 4: Only isonline set';
    EXEC [core].[usp_UpsertServerDatabase]
        @serverid = 4,
        @servername = N'Test4',
        @instancename = N'ni01',
        @databasename = N'Test4_OnlyIsOnline',
        @owner = NULL,
        @createdate = NULL,
        @recoverymodel = NULL,
        @status = NULL,
        @compatibilitylevel = NULL,
        @collation = NULL,
        @isonline = 1,
        @isuserdb = NULL,
        @iswidelocalerestricted = NULL,
        @size_mb = NULL,
        @unallocatedspace_mb = NULL,
        @reserved_mb = NULL,
        @accessed = NULL;
    PRINT '✓ Test 4 Success';
END TRY
BEGIN CATCH
    PRINT '✗ Test 4 Failed: ' + ERROR_MESSAGE();
END CATCH

SELECT 'Summary' as Result;
SELECT COUNT(*) as InsertedRecords FROM [core].[sqlserverdatabase] WHERE databasename LIKE 'Test_%';
SELECT COUNT(*) as AuditRecords FROM [log].[sqlserverdatabase] WHERE databasename LIKE 'Test_%';
