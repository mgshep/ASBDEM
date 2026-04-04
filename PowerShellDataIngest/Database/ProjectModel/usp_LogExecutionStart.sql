
CREATE PROCEDURE [log].[usp_LogExecutionStart]
    @logtype NVARCHAR(50),
    -- 'SQL' or 'PowerShell'
    @sourcename NVARCHAR(255),
    -- Procedure name or script name
    @activity NVARCHAR(MAX),
    -- Description of activity
    @createdby NVARCHAR(255) = NULL
-- Optional: user or script name
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @logid INT;

    INSERT INTO [log].[executionlog]
        (logtype, sourcename, activity, status, starttime, createdby)
    VALUES
        (@logtype, @sourcename, @activity, 'In Progress', GETDATE(), @createdby);

    SET @logid = SCOPE_IDENTITY();

    SELECT @logid AS logid;

    RETURN 0;
END

GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Logs the start of an execution with status set to In Progress', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'PROCEDURE', @level1name = N'usp_LogExecutionStart';


GO

