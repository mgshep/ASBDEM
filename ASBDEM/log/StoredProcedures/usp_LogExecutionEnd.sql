
CREATE PROCEDURE [log].[usp_LogExecutionEnd]
    @logid INT,
    -- Log ID from usp_LogExecutionStart
    @status NVARCHAR(50),
    -- 'Success', 'Warning', or 'Error'
    @errormessage NVARCHAR(MAX) = NULL,
    -- Error message if applicable
    @errorcode NVARCHAR(50) = NULL,
    -- Error code if applicable
    @recordsaffected INT = NULL,
    -- Number of records affected
    @additionaldata NVARCHAR(MAX) = NULL
-- Additional context data
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @starttime DATETIME;
    DECLARE @executiontime INT;

    -- Get the start time to calculate execution time
    SELECT @starttime = starttime
    FROM [log].[executionlog]
    WHERE logid = @logid;

    -- Calculate execution time in milliseconds
    IF @starttime IS NOT NULL
    BEGIN
        SET @executiontime = DATEDIFF(MILLISECOND, @starttime, GETDATE());
    END

    -- Update the log entry with completion information
    UPDATE [log].[executionlog]
    SET
        status = @status,
        errormessage = @errormessage,
        errorcode = @errorcode,
        recordsaffected = @recordsaffected,
        executiontime = @executiontime,
        endtime = GETDATE(),
        additionaldata = @additionaldata
    WHERE logid = @logid;

    RETURN 0;
END
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Logs the completion of an execution with status, errors, and execution time', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'PROCEDURE', @level1name = N'usp_LogExecutionEnd';
GO

GRANT EXECUTE
    ON OBJECT::[log].[usp_LogExecutionEnd] TO [PowerShellUser]
    AS [dbo];
GO

