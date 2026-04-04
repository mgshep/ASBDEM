
CREATE PROCEDURE [log].[usp_LogActivity]
    @logtype NVARCHAR(50),
    -- 'SQL' or 'PowerShell'
    @sourcename NVARCHAR(255),
    -- Procedure name or script name
    @activity NVARCHAR(MAX),
    -- Description of activity
    @status NVARCHAR(50),
    -- 'Success', 'Warning', or 'Error'
    @errormessage NVARCHAR(MAX) = NULL,
    -- Error message if applicable
    @recordsaffected INT = NULL,
    -- Number of records affected
    @createdby NVARCHAR(255) = NULL
-- Optional: user or script name
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [log].[executionlog]
        (logtype, sourcename, activity, status, errormessage, recordsaffected, starttime, createdby)
    VALUES
        (@logtype, @sourcename, @activity, @status, @errormessage, @recordsaffected, GETDATE(), @createdby);

    RETURN 0;
END

GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Logs a single activity without start/end time tracking', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'PROCEDURE', @level1name = N'usp_LogActivity';


GO

