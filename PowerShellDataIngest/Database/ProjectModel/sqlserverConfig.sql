CREATE TABLE [core].[sqlserverConfig] (
    [configid]        INT            IDENTITY (1, 1) NOT NULL,
    [servername]      NVARCHAR (100) NOT NULL,
    [instancename]    NVARCHAR (100) NULL,
    [configname]      NVARCHAR (200) NOT NULL,
    [configvalue]     NVARCHAR (MAX) NULL,
    [configtype]      NVARCHAR (100) NULL,
    [minimum]         NVARCHAR (100) NULL,
    [maximum]         NVARCHAR (100) NULL,
    [isstatic]        BIT            NULL,
    [requiresrestart] BIT            NULL,
    [captured]        DATETIME       DEFAULT (getdate()) NOT NULL,
    [serverid]        INT            NULL,
    PRIMARY KEY CLUSTERED ([configid] ASC),
    CONSTRAINT [FK_sqlserverConfig_servers] FOREIGN KEY ([serverid]) REFERENCES [core].[servers] ([serverid]) ON DELETE CASCADE ON UPDATE CASCADE
);


GO

CREATE NONCLUSTERED INDEX [IX_sqlserverConfig_captured]
    ON [core].[sqlserverConfig]([captured] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_sqlserverConfig_servername]
    ON [core].[sqlserverConfig]([servername] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_sqlserverConfig_servername_configname]
    ON [core].[sqlserverConfig]([servername] ASC, [configname] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_sqlserverConfig_serverid]
    ON [core].[sqlserverConfig]([serverid] ASC);


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Maximum allowed value for the configuration option', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'maximum';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier for the configuration record', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'configid';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Type of the configuration option', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'configtype';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Current value of the configuration option', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'configvalue';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Stores SQL Server instance configuration settings captured from sp_configure', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Whether the configuration requires a server restart to take effect (1 = requires restart, 0 = no restart needed)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'requiresrestart';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Instance name of the SQL Server', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'instancename';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Foreign key reference to core.servers', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'serverid';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Whether the configuration is static (1 = static, 0 = dynamic)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'isstatic';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Name of the server', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'servername';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Minimum allowed value for the configuration option', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'minimum';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Name of the configuration option (e.g., max degree of parallelism, cost threshold for parallelism)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'configname';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Date and time when the configuration was captured', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverConfig', @level2type = N'COLUMN', @level2name = N'captured';


GO

