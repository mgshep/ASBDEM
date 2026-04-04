CREATE TABLE [log].[sqlserverdatabase] (
    [logid]        BIGINT         IDENTITY (1, 1) NOT NULL,
    [serverid]     INT            NULL,
    [servername]   NVARCHAR (100) NULL,
    [instancename] NVARCHAR (100) NULL,
    [databasename] NVARCHAR (100) NULL,
    [action]       NVARCHAR (50)  NULL,
    [property]     NVARCHAR (100) NULL,
    [oldvalue]     NVARCHAR (MAX) NULL,
    [newvalue]     NVARCHAR (MAX) NULL,
    [changedby]    NVARCHAR (100) NULL,
    [changeddate]  DATETIME       DEFAULT (getdate()) NULL,
    PRIMARY KEY CLUSTERED ([logid] ASC)
);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Audit log for database information changes', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'sqlserverdatabase';
GO

CREATE NONCLUSTERED INDEX [IX_log_sqlserverdatabase_servername_database]
    ON [log].[sqlserverdatabase]([servername] ASC, [databasename] ASC, [changeddate] ASC)
    INCLUDE([action], [property], [oldvalue], [newvalue]);
GO

CREATE NONCLUSTERED INDEX [IX_log_sqlserverdatabase_action]
    ON [log].[sqlserverdatabase]([action] ASC, [changeddate] ASC)
    INCLUDE([serverid], [databasename], [property]);
GO

