
CREATE VIEW [log].[vw_ExecutionLog]
AS
    SELECT
        logid,
        logtype,
        sourcename,
        activity,
        status,
        CASE 
            WHEN errormessage IS NOT NULL THEN errormessage
            ELSE 'No errors'
        END AS errormessage,
        errorcode,
        recordsaffected,
        executiontime AS executiontime_ms,
        CONVERT(VARCHAR(20), executiontime, 121) AS executiontime_formatted,
        starttime,
        endtime,
        DATEDIFF(SECOND, starttime, endtime) AS duration_seconds,
        createdby,
        additionaldata
    FROM [log].[executionlog];
GO

GRANT SELECT
    ON OBJECT::[log].[vw_ExecutionLog] TO [PowerShellUser]
    AS [dbo];
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Formatted view of execution logs with calculated fields for easy reporting', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'VIEW', @level1name = N'vw_ExecutionLog';
GO

