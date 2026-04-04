-- ============================================================================
-- Server Configuration Pivot Stored Procedure (Dynamic)
-- ============================================================================
-- Purpose: Dynamically pivots server configuration data from name-value pairs
--          to columns. New configuration properties are automatically included
--          without procedure modifications.
-- Schema: core
-- Parameters:
--   @ServerName NVARCHAR(100) - Filter by specific server (optional, NULL for all)
-- ============================================================================

CREATE PROCEDURE [core].[usp_GetServerConfigPivot]
    @ServerName NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DynamicColumns NVARCHAR(MAX);
    DECLARE @DynamicSQL NVARCHAR(MAX);

    -- Step 1: Build dynamic column list from unique configuration names
    -- This ensures all config properties are included, even new ones
    SELECT @DynamicColumns = STRING_AGG('[' + configname + ']', ',')
    FROM (
        SELECT DISTINCT configname
        FROM [core].[sqlserverConfig]
        WHERE (@ServerName IS NULL OR servername = @ServerName)
    ) AS UniqueConfigs;

    -- If no data found, return empty result set
    IF @DynamicColumns IS NULL
    BEGIN
        SELECT
            CAST(NULL AS NVARCHAR(100)) AS servername,
            CAST(NULL AS NVARCHAR(100)) AS instancename,
            CAST(NULL AS DATETIME) AS captured
        WHERE 1 = 0;
        RETURN;
    END

    -- Step 2: Build dynamic PIVOT query
    -- Group by servername and instancename only to get one row per server
    SET @DynamicSQL = N'
    WITH LatestConfigs AS
    (
        SELECT
            servername,
            instancename,
            configname,
            configvalue,
            ROW_NUMBER() OVER (PARTITION BY servername, instancename, configname ORDER BY captured DESC) AS rn
        FROM [core].[sqlserverConfig]
        ' + (CASE WHEN @ServerName IS NOT NULL THEN 'WHERE servername = @ServerName' ELSE '' END) + '
    )
    SELECT *
    FROM
    (
        SELECT
            servername,
            instancename,
            configname,
            configvalue
        FROM LatestConfigs
        WHERE rn = 1
    ) AS Source
    PIVOT
    (
        MAX(configvalue)
        FOR configname IN (' + @DynamicColumns + ')
    ) AS PivotTable
    ORDER BY servername';

    -- Step 3: Execute dynamic SQL with parameter
    IF @ServerName IS NOT NULL
    BEGIN
        EXECUTE [master].[dbo].[sp_executesql] @DynamicSQL,
            N'@ServerName NVARCHAR(100)',
            @ServerName = @ServerName;
    END
    ELSE
    BEGIN
        EXECUTE [master].[dbo].[sp_executesql] @DynamicSQL;
    END
END
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Optional. Filter results to a specific server name. If NULL, returns results for all servers.', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'PROCEDURE', @level1name = N'usp_GetServerConfigPivot', @level2type = N'PARAMETER', @level2name = N'@ServerName';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Dynamically pivots server configuration settings into columns. Automatically includes new configuration properties without code changes.', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'PROCEDURE', @level1name = N'usp_GetServerConfigPivot';
GO

