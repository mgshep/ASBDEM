CREATE TABLE [core].[sqlserverProperties] (
    [propertyid]    INT            IDENTITY (1, 1) NOT NULL,
    [servername]    NVARCHAR (100) NOT NULL,
    [instancename]  NVARCHAR (100) NULL,
    [propertyname]  NVARCHAR (200) NOT NULL,
    [propertyvalue] NVARCHAR (MAX) NULL,
    [propertytype]  NVARCHAR (50)  NULL,
    [captured]      DATETIME       DEFAULT (getdate()) NOT NULL,
    [serverid]      INT            NULL,
    PRIMARY KEY CLUSTERED ([propertyid] ASC),
    CONSTRAINT [FK_sqlserverProperties_servers] FOREIGN KEY ([serverid]) REFERENCES [core].[servers] ([serverid]) ON DELETE CASCADE ON UPDATE CASCADE
);


GO

CREATE NONCLUSTERED INDEX [IX_sqlserverProperties_servername_propertyname]
    ON [core].[sqlserverProperties]([servername] ASC, [propertyname] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_sqlserverProperties_servername]
    ON [core].[sqlserverProperties]([servername] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_sqlserverProperties_serverid]
    ON [core].[sqlserverProperties]([serverid] ASC);


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Date and time when the property was captured', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties', @level2type = N'COLUMN', @level2name = N'captured';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Stores SQL Server instance properties in key-value format for inventory tracking', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Name of the server', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties', @level2type = N'COLUMN', @level2name = N'servername';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Name of the property (e.g., Edition, BuildNumber, ProductVersion)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties', @level2type = N'COLUMN', @level2name = N'propertyname';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Value of the property', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties', @level2type = N'COLUMN', @level2name = N'propertyvalue';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier for the property record', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties', @level2type = N'COLUMN', @level2name = N'propertyid';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Instance name of the SQL Server', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties', @level2type = N'COLUMN', @level2name = N'instancename';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Foreign key reference to core.servers', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties', @level2type = N'COLUMN', @level2name = N'serverid';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Type of the property (e.g., Information, Configuration)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverProperties', @level2type = N'COLUMN', @level2name = N'propertytype';


GO

