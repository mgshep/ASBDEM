
CREATE PROCEDURE [core].[usp_UpsertServerDatabase]
    @serverid INT,
    @servername NVARCHAR(100),
    @instancename NVARCHAR(100),
    @databasename NVARCHAR(100),
    @owner NVARCHAR(100),
    @createdate DATETIME,
    @recoverymodel NVARCHAR(50),
    @status NVARCHAR(50),
    @compatibilitylevel INT,
    @collation NVARCHAR(100),
    @isonline BIT,
    @isuserdb BIT,
    @iswidelocalerestricted BIT,
    @size_mb FLOAT,
    @unallocatedspace_mb FLOAT,
    @reserved_mb FLOAT,
    @accessed DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    -- Table variable to capture MERGE output
    DECLARE @MergeOutput TABLE (
        Action NVARCHAR(10),
        ServerID INT,
        ServerName NVARCHAR(100),
        InstanceName NVARCHAR(100),
        DatabaseName NVARCHAR(100),
        OldOwner NVARCHAR(100),
        NewOwner NVARCHAR(100),
        OldRecoveryModel NVARCHAR(50),
        NewRecoveryModel NVARCHAR(50),
        OldStatus NVARCHAR(50),
        NewStatus NVARCHAR(50),
        OldIsOnline BIT,
        NewIsOnline BIT,
        OldCompatibilityLevel NVARCHAR(50),
        NewCompatibilityLevel NVARCHAR(50),
        OldCollation NVARCHAR(100),
        NewCollation NVARCHAR(100),
        OldIsUserDB NVARCHAR(1),
        NewIsUserDB NVARCHAR(1),
        OldIsWideLocaleRestricted NVARCHAR(1),
        NewIsWideLocaleRestricted NVARCHAR(1),
        OldSize_MB NVARCHAR(50),
        NewSize_MB NVARCHAR(50),
        OldUnallocatedSpace_MB NVARCHAR(50),
        NewUnallocatedSpace_MB NVARCHAR(50),
        OldReserved_MB NVARCHAR(50),
        NewReserved_MB NVARCHAR(50),
        OldAccessed NVARCHAR(100),
        NewAccessed NVARCHAR(100)
    );

    -- MERGE with OUTPUT to capture all changes
    MERGE INTO [core].[sqlserverdatabase] AS target
    USING (SELECT @serverid AS serverid, @servername AS servername, @instancename AS instancename,
        @databasename AS databasename, @owner AS owner, @createdate AS createdate,
        @recoverymodel AS recoverymodel, @status AS status, @compatibilitylevel AS compatibilitylevel,
        @collation AS collation, @isonline AS isonline, @isuserdb AS isuserdb,
        @iswidelocalerestricted AS iswidelocalerestricted, @size_mb AS size_mb,
        @unallocatedspace_mb AS unallocatedspace_mb, @reserved_mb AS reserved_mb,
        @accessed AS accessed) AS source
        ON target.serverid = source.serverid AND target.databasename = source.databasename
    WHEN MATCHED THEN
        UPDATE SET
            owner = source.owner,
            recoverymodel = source.recoverymodel,
            status = source.status,
            compatibilitylevel = source.compatibilitylevel,
            collation = source.collation,
            isonline = source.isonline,
            isuserdb = source.isuserdb,
            iswidelocalerestricted = source.iswidelocalerestricted,
            size_mb = source.size_mb,
            unallocatedspace_mb = source.unallocatedspace_mb,
            reserved_mb = source.reserved_mb,
            accessed = source.accessed,
            captured = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (serverid, servername, instancename, databasename, owner, createdate, 
                recoverymodel, status, compatibilitylevel, collation, isonline, isuserdb,
                iswidelocalerestricted, size_mb, unallocatedspace_mb, reserved_mb, accessed)
        VALUES (source.serverid, source.servername, source.instancename, source.databasename,
                source.owner, source.createdate, source.recoverymodel, source.status,
                source.compatibilitylevel, source.collation, source.isonline, source.isuserdb,
                source.iswidelocalerestricted, source.size_mb, source.unallocatedspace_mb,
                source.reserved_mb, source.accessed)
    OUTPUT $action, 
           inserted.serverid, 
           inserted.servername, 
           inserted.instancename, 
           inserted.databasename,
           deleted.owner,
           inserted.owner,
           deleted.recoverymodel,
           inserted.recoverymodel,
           deleted.status,
           inserted.status,
           deleted.isonline,
           inserted.isonline,
           CAST(ISNULL(CAST(deleted.compatibilitylevel AS NVARCHAR(50)), '') AS NVARCHAR(50)),
           CAST(ISNULL(CAST(inserted.compatibilitylevel AS NVARCHAR(50)), '') AS NVARCHAR(50)),
           ISNULL(deleted.collation, ''),
           ISNULL(inserted.collation, ''),
           CAST(ISNULL(CAST(deleted.isuserdb AS NVARCHAR(1)), '') AS NVARCHAR(1)),
           CAST(ISNULL(CAST(inserted.isuserdb AS NVARCHAR(1)), '') AS NVARCHAR(1)),
           CAST(ISNULL(CAST(deleted.iswidelocalerestricted AS NVARCHAR(1)), '') AS NVARCHAR(1)),
           CAST(ISNULL(CAST(inserted.iswidelocalerestricted AS NVARCHAR(1)), '') AS NVARCHAR(1)),
           CAST(ISNULL(CAST(deleted.size_mb AS NVARCHAR(50)), '') AS NVARCHAR(50)),
           CAST(ISNULL(CAST(inserted.size_mb AS NVARCHAR(50)), '') AS NVARCHAR(50)),
           CAST(ISNULL(CAST(deleted.unallocatedspace_mb AS NVARCHAR(50)), '') AS NVARCHAR(50)),
           CAST(ISNULL(CAST(inserted.unallocatedspace_mb AS NVARCHAR(50)), '') AS NVARCHAR(50)),
           CAST(ISNULL(CAST(deleted.reserved_mb AS NVARCHAR(50)), '') AS NVARCHAR(50)),
           CAST(ISNULL(CAST(inserted.reserved_mb AS NVARCHAR(50)), '') AS NVARCHAR(50)),
           CAST(ISNULL(CONVERT(NVARCHAR(100), deleted.accessed), '') AS NVARCHAR(100)),
           CAST(ISNULL(CONVERT(NVARCHAR(100), inserted.accessed), '') AS NVARCHAR(100))
    INTO @MergeOutput;

    -- Log all database property changes using CROSS APPLY to convert wide MERGE output to tall audit format
    IF @owner IS NOT NULL OR @recoverymodel IS NOT NULL OR @status IS NOT NULL OR @isonline IS NOT NULL
        OR @compatibilitylevel IS NOT NULL OR @collation IS NOT NULL OR @isuserdb IS NOT NULL
        OR @iswidelocalerestricted IS NOT NULL OR @size_mb IS NOT NULL OR @unallocatedspace_mb IS NOT NULL
        OR @reserved_mb IS NOT NULL OR @accessed IS NOT NULL
    BEGIN
        INSERT INTO [log].[sqlserverdatabase]
            (serverid, servername, instancename, databasename, action, property, oldvalue, newvalue, changedby)
        SELECT
            mo.ServerID, mo.ServerName, mo.InstanceName, mo.DatabaseName, mo.Action,
            props.PropertyName, props.OldValue, props.NewValue, SYSTEM_USER
        FROM @MergeOutput mo
        CROSS APPLY (
            VALUES
                ('owner', NULLIF(mo.OldOwner, mo.NewOwner), mo.NewOwner, CAST(@owner AS NVARCHAR(MAX))),
                ('recoverymodel', NULLIF(mo.OldRecoveryModel, mo.NewRecoveryModel), mo.NewRecoveryModel, CAST(@recoverymodel AS NVARCHAR(MAX))),
                ('status', NULLIF(mo.OldStatus, mo.NewStatus), mo.NewStatus, CAST(@status AS NVARCHAR(MAX))),
                ('isonline', NULLIF(CAST(mo.OldIsOnline AS NVARCHAR(1)), CAST(mo.NewIsOnline AS NVARCHAR(1))), CAST(mo.NewIsOnline AS NVARCHAR(1)), CAST(@isonline AS NVARCHAR(MAX))),
                ('compatibilitylevel', NULLIF(mo.OldCompatibilityLevel, mo.NewCompatibilityLevel), mo.NewCompatibilityLevel, CAST(@compatibilitylevel AS NVARCHAR(MAX))),
                ('collation', NULLIF(mo.OldCollation, mo.NewCollation), mo.NewCollation, CAST(@collation AS NVARCHAR(MAX))),
                ('isuserdb', NULLIF(mo.OldIsUserDB, mo.NewIsUserDB), mo.NewIsUserDB, CAST(@isuserdb AS NVARCHAR(MAX))),
                ('iswidelocalerestricted', NULLIF(mo.OldIsWideLocaleRestricted, mo.NewIsWideLocaleRestricted), mo.NewIsWideLocaleRestricted, CAST(@iswidelocalerestricted AS NVARCHAR(MAX))),
                ('size_mb', NULLIF(mo.OldSize_MB, mo.NewSize_MB), mo.NewSize_MB, CAST(@size_mb AS NVARCHAR(MAX))),
                ('unallocatedspace_mb', NULLIF(mo.OldUnallocatedSpace_MB, mo.NewUnallocatedSpace_MB), mo.NewUnallocatedSpace_MB, CAST(@unallocatedspace_mb AS NVARCHAR(MAX))),
                ('reserved_mb', NULLIF(mo.OldReserved_MB, mo.NewReserved_MB), mo.NewReserved_MB, CAST(@reserved_mb AS NVARCHAR(MAX))),
                ('accessed', NULLIF(mo.OldAccessed, mo.NewAccessed), mo.NewAccessed, CAST(@accessed AS NVARCHAR(MAX)))
        ) AS props(PropertyName, OldValue, NewValue, ParamValue)
        WHERE (mo.Action IN ('INSERT', 'UPDATE', 'DELETE') OR props.OldValue IS NOT NULL AND props.OldValue != props.NewValue)
            AND ParamValue IS NOT NULL;
    END

END

GO

