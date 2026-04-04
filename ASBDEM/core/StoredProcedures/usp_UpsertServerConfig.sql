-- ============================================================================
-- Upsert Server Configuration with Audit Logging
-- ============================================================================
-- Purpose: Insert or update server configuration and log all changes to audit table
-- ============================================================================

CREATE   PROCEDURE [core].[usp_UpsertServerConfig]
    @serverid INT,
    @servername NVARCHAR(100),
    @instancename NVARCHAR(100),
    @configname NVARCHAR(200),
    @configvalue NVARCHAR(MAX),
    @configtype NVARCHAR(100),
    @minimum NVARCHAR(100),
    @maximum NVARCHAR(100),
    @isstatic BIT,
    @requiresrestart BIT,
    @success BIT = 0 OUTPUT,
    @errormessage NVARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MergeOutput TABLE (
        Action NVARCHAR(10),
        ServerID INT,
        ServerName NVARCHAR(100),
        InstanceName NVARCHAR(100),
        ConfigName NVARCHAR(200),
        OldValue NVARCHAR(MAX),
        NewValue NVARCHAR(MAX),
        OldConfigType NVARCHAR(100),
        NewConfigType NVARCHAR(100),
        OldMinimum NVARCHAR(100),
        NewMinimum NVARCHAR(100),
        OldMaximum NVARCHAR(100),
        NewMaximum NVARCHAR(100),
        OldIsStatic NVARCHAR(1),
        NewIsStatic NVARCHAR(1),
        OldRequiresRestart NVARCHAR(1),
        NewRequiresRestart NVARCHAR(1)
    );

    BEGIN TRY
        -- Perform the MERGE operation with OUTPUT
        MERGE INTO [core].[sqlserverConfig] AS target
        USING (SELECT @serverid, @servername, @instancename, @configname) AS source(serverid, servername, instancename, configname)
        ON target.serverid = source.serverid
        AND target.configname = source.configname
        WHEN MATCHED THEN
            UPDATE SET
                configvalue = @configvalue,
                configtype = @configtype,
                minimum = @minimum,
                maximum = @maximum,
                isstatic = @isstatic,
                requiresrestart = @requiresrestart,
                captured = GETDATE()
        WHEN NOT MATCHED THEN
            INSERT (serverid, servername, instancename, configname, configvalue, configtype, minimum, maximum, isstatic, requiresrestart, captured)
            VALUES (@serverid, @servername, @instancename, @configname, @configvalue, @configtype, @minimum, @maximum, @isstatic, @requiresrestart, GETDATE())
        OUTPUT $action, 
               inserted.serverid, 
               inserted.servername, 
               inserted.instancename, 
               inserted.configname,
               deleted.configvalue,
               inserted.configvalue,
               deleted.configtype,
               inserted.configtype,
               deleted.minimum,
               inserted.minimum,
               deleted.maximum,
               inserted.maximum,
               CAST(ISNULL(deleted.isstatic, 0) AS NVARCHAR(1)),
               CAST(ISNULL(inserted.isstatic, 0) AS NVARCHAR(1)),
               CAST(ISNULL(deleted.requiresrestart, 0) AS NVARCHAR(1)),
               CAST(ISNULL(inserted.requiresrestart, 0) AS NVARCHAR(1))
        INTO @MergeOutput;

        -- Log all configuration metadata changes using CROSS APPLY to normalize into key-value rows
        IF @configvalue IS NOT NULL OR @configtype IS NOT NULL OR @minimum IS NOT NULL
        OR @maximum IS NOT NULL OR @isstatic IS NOT NULL OR @requiresrestart IS NOT NULL
        BEGIN
        INSERT INTO [log].[sqlserverConfig]
            (serverid, servername, instancename, configname, action, property, oldvalue, newvalue, changedby, changeddate)
        SELECT
            mo.ServerID, mo.ServerName, mo.InstanceName, mo.ConfigName, mo.Action,
            props.PropertyName, props.OldValue, props.NewValue,
            SYSTEM_USER,
            GETDATE()
        FROM @MergeOutput mo
        CROSS APPLY (
            VALUES
                ('value', NULLIF(mo.OldValue, mo.NewValue), mo.NewValue, CAST(@configvalue AS NVARCHAR(MAX))),
                ('type', NULLIF(mo.OldConfigType, mo.NewConfigType), mo.NewConfigType, CAST(@configtype AS NVARCHAR(MAX))),
                ('minimum', NULLIF(mo.OldMinimum, mo.NewMinimum), mo.NewMinimum, CAST(@minimum AS NVARCHAR(MAX))),
                ('maximum', NULLIF(mo.OldMaximum, mo.NewMaximum), mo.NewMaximum, CAST(@maximum AS NVARCHAR(MAX))),
                ('isstatic', NULLIF(mo.OldIsStatic, mo.NewIsStatic), mo.NewIsStatic, CAST(@isstatic AS NVARCHAR(1))),
                ('requiresrestart', NULLIF(mo.OldRequiresRestart, mo.NewRequiresRestart), mo.NewRequiresRestart, CAST(@requiresrestart AS NVARCHAR(1)))
        ) AS props(PropertyName, OldValue, NewValue, ParamValue)
        WHERE (mo.Action IN ('INSERT', 'UPDATE', 'DELETE') OR props.OldValue IS NOT NULL AND props.OldValue != props.NewValue)
            AND ParamValue IS NOT NULL;
    END

        SET @success = 1;
        SET @errormessage = NULL;
    END TRY
    BEGIN CATCH
        SET @success = 0;
        SET @errormessage = ERROR_MESSAGE();
    END CATCH

    RETURN 0;
END
GO

GRANT EXECUTE
    ON OBJECT::[core].[usp_UpsertServerConfig] TO [PowerShellUser]
    AS [dbo];
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Inserts or updates server configuration and logs changes to audit table', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'PROCEDURE', @level1name = N'usp_UpsertServerConfig';
GO

