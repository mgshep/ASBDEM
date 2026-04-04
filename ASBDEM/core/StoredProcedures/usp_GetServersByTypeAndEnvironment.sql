CREATE PROCEDURE [core].[usp_GetServersByTypeAndEnvironment]
    @servertypename NVARCHAR(100) = NULL,
    @environment NVARCHAR(10) = NULL,
    @isactive BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @environment IS NOT NULL
            AND @environment NOT IN ('Dev', 'QA', 'FST', 'Prod')
        BEGIN
            THROW 50001, 'Invalid environment value. Valid values are: Dev, QA, FST, Prod', 1;
        END;

        SELECT
            s.serverid,
            s.servername,
            s.servertypeid,
            st.servertypename,
            st.description AS servertypedescription,
            s.environment,
            s.serverlocation,
            s.firstdiscovered,
            s.lastdiscovery,
            s.serverdecomdate,
            s.servertype AS legacyservertype,
            st.isactive AS servertypeisactive,
            st.createddate AS servertypecreateddate
        FROM [core].[servers] s
        LEFT JOIN [core].[servertype] st ON s.servertypeid = st.servertypeid
        WHERE (st.servertypename = @servertypename OR @servertypename IS NULL)
            AND (s.environment = @environment OR @environment IS NULL)
            AND (st.isactive = @isactive OR @isactive IS NULL)
        ORDER BY s.servername;
    END TRY
    BEGIN CATCH
        SELECT
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_SEVERITY() AS ErrorSeverity,
            ERROR_STATE() AS ErrorState,
            ERROR_PROCEDURE() AS ErrorProcedure,
            ERROR_LINE() AS ErrorLine,
            ERROR_MESSAGE() AS ErrorMessage;

        RETURN -1;
    END CATCH;
END;
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Server type name to filter by (e.g., ''SQLServer'', ''Azure SQLVM'', ''Azure MI'', etc.). Optional - NULL returns all types.', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'PROCEDURE', @level1name = N'usp_GetServersByTypeAndEnvironment', @level2type = N'PARAMETER', @level2name = N'@servertypename';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Environment to filter by: Dev, QA, FST, or Prod (optional - NULL returns all environments)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'PROCEDURE', @level1name = N'usp_GetServersByTypeAndEnvironment', @level2type = N'PARAMETER', @level2name = N'@environment';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Server type active status filter: 1 for active, 0 for inactive, NULL for all (optional)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'PROCEDURE', @level1name = N'usp_GetServersByTypeAndEnvironment', @level2type = N'PARAMETER', @level2name = N'@isactive';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Retrieves servers filtered by server type name, environment, and/or active status. All parameters are optional.', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'PROCEDURE', @level1name = N'usp_GetServersByTypeAndEnvironment';
GO