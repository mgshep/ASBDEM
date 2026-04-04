-- ============================================================================
-- Upsert Server Property with Audit Logging
-- ============================================================================
-- Purpose: Insert or update server property and log all changes to audit table
-- Uses OUTPUT clause for efficient change tracking
-- ============================================================================

CREATE   PROCEDURE [core].[usp_UpsertServerProperty]
    @serverid INT,
    @servername NVARCHAR(100),
    @instancename NVARCHAR(100),
    @propertyname NVARCHAR(200),
    @propertyvalue NVARCHAR(MAX),
    @propertytype NVARCHAR(50),
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
        PropertyName NVARCHAR(200),
        OldValue NVARCHAR(MAX),
        NewValue NVARCHAR(MAX),
        OldPropertyType NVARCHAR(50),
        NewPropertyType NVARCHAR(50)
    );

    BEGIN TRY
        -- Perform the MERGE operation with OUTPUT
        MERGE INTO [core].[sqlserverProperties] AS target
        USING (SELECT @serverid, @servername, @instancename, @propertyname) AS source(serverid, servername, instancename, propertyname)
        ON target.serverid = source.serverid
        AND target.propertyname = source.propertyname
        WHEN MATCHED THEN
            UPDATE SET
                propertyvalue = @propertyvalue,
                propertytype = @propertytype,
                captured = GETDATE()
        WHEN NOT MATCHED THEN
            INSERT (serverid, servername, instancename, propertyname, propertyvalue, propertytype, captured)
            VALUES (@serverid, @servername, @instancename, @propertyname, @propertyvalue, @propertytype, GETDATE())
        OUTPUT $action, 
               inserted.serverid, 
               inserted.servername, 
               inserted.instancename, 
               inserted.propertyname,
               deleted.propertyvalue,
               inserted.propertyvalue,
               deleted.propertytype,
               inserted.propertytype
        INTO @MergeOutput;

        -- Log all property metadata changes using CROSS APPLY to normalize into key-value rows
        IF @propertyvalue IS NOT NULL OR @propertytype IS NOT NULL
        BEGIN
        INSERT INTO [log].[sqlserverProperties]
            (serverid, servername, instancename, propertyname, action, property, oldvalue, newvalue, changedby, changeddate)
        SELECT
            mo.ServerID, mo.ServerName, mo.InstanceName, mo.PropertyName, mo.Action,
            props.PropertyName, props.OldValue, props.NewValue,
            SYSTEM_USER,
            GETDATE()
        FROM @MergeOutput mo
        CROSS APPLY (
            VALUES
                ('value', NULLIF(mo.OldValue, mo.NewValue), mo.NewValue, CAST(@propertyvalue AS NVARCHAR(MAX))),
                ('type', NULLIF(mo.OldPropertyType, mo.NewPropertyType), mo.NewPropertyType, CAST(@propertytype AS NVARCHAR(MAX)))
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

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Inserts or updates server property and logs changes to audit table', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'PROCEDURE', @level1name = N'usp_UpsertServerProperty';


GO

