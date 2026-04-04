-- Verify CAST fixes are deployed in procedures
DECLARE @def_property NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('[core].[usp_UpsertServerProperty]'));
DECLARE @def_config NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('[core].[usp_UpsertServerConfig]'));

    SELECT
        'usp_UpsertServerProperty' AS [Procedure],
        CASE WHEN @def_property LIKE '%CAST(@propertyvalue AS NVARCHAR(MAX))%' THEN 'FIXED' ELSE 'NOT FIXED' END AS [Status]
UNION ALL
    SELECT
        'usp_UpsertServerConfig',
        CASE WHEN @def_config LIKE '%CAST(@configvalue AS NVARCHAR(MAX))%' THEN 'FIXED' ELSE 'NOT FIXED' END
