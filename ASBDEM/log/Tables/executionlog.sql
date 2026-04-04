CREATE TABLE [log].[executionlog] (
    [logid]           INT            IDENTITY (1, 1) NOT NULL,
    [logtype]         NVARCHAR (50)  NOT NULL,
    [sourcename]      NVARCHAR (255) NOT NULL,
    [activity]        NVARCHAR (MAX) NOT NULL,
    [status]          NVARCHAR (50)  NOT NULL,
    [errormessage]    NVARCHAR (MAX) NULL,
    [errorcode]       NVARCHAR (50)  NULL,
    [recordsaffected] INT            NULL,
    [executiontime]   INT            NULL,
    [starttime]       DATETIME       DEFAULT (getdate()) NOT NULL,
    [endtime]         DATETIME       NULL,
    [createdby]       NVARCHAR (255) NULL,
    [additionaldata]  NVARCHAR (MAX) NULL,
    PRIMARY KEY CLUSTERED ([logid] ASC)
);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier for the log entry', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'logid';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Type of log entry: SQL or PowerShell', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'logtype';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Source of the log entry (stored procedure name or script name)', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'sourcename';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Description of the activity being logged', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'activity';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Status of the execution: Success, Warning, or Error', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'status';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Error message if an error occurred', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'errormessage';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Error code if an error occurred', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'errorcode';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Number of records affected by the operation', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'recordsaffected';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Execution time in milliseconds', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'executiontime';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Timestamp when execution started', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'starttime';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Timestamp when execution ended', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'endtime';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'User or system that created the log entry', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'createdby';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Additional context data (JSON format recommended)', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog', @level2type = N'COLUMN', @level2name = N'additionaldata';
GO

CREATE NONCLUSTERED INDEX [IX_executionlog_status]
    ON [log].[executionlog]([status] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_executionlog_starttime]
    ON [log].[executionlog]([starttime] DESC);
GO

CREATE NONCLUSTERED INDEX [IX_executionlog_sourcename]
    ON [log].[executionlog]([sourcename] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_executionlog_logtype]
    ON [log].[executionlog]([logtype] ASC);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Captures execution logs for SQL stored procedures and PowerShell scripts', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'executionlog';
GO

GRANT SELECT
    ON OBJECT::[log].[executionlog] TO [PowerShellUser]
    AS [dbo];
GO

