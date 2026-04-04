CREATE TABLE [log].[sqlserverConfig] (
    [logid]        INT            IDENTITY (1, 1) NOT NULL,
    [serverid]     INT            NOT NULL,
    [servername]   NVARCHAR (100) NOT NULL,
    [instancename] NVARCHAR (100) NULL,
    [configname]   NVARCHAR (200) NOT NULL,
    [action]       NVARCHAR (50)  NOT NULL,
    [property]     NVARCHAR (100) NULL,
    [oldvalue]     NVARCHAR (MAX) NULL,
    [newvalue]     NVARCHAR (MAX) NULL,
    [changedby]    NVARCHAR (128) DEFAULT (suser_sname()) NULL,
    [changeddate]  DATETIME       DEFAULT (getdate()) NOT NULL,
    PRIMARY KEY CLUSTERED ([logid] ASC)
);
GO

CREATE NONCLUSTERED INDEX [IX_log_sqlserverConfig_servername_configname]
    ON [log].[sqlserverConfig]([servername] ASC, [configname] ASC, [changeddate] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_log_sqlserverConfig_action]
    ON [log].[sqlserverConfig]([action] ASC, [changeddate] ASC);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Audit log for changes to server configuration settings. Each property change is logged as a separate row with property column indicating the specific setting (value, type, minimum, maximum, isstatic, requiresrestart).', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'sqlserverConfig';
GO

