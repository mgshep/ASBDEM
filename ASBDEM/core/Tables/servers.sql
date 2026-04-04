CREATE TABLE [core].[servers] (
    [serverid]        INT            IDENTITY (1, 1) NOT NULL,
    [servername]      NVARCHAR (100) NOT NULL,
    [firstdiscovered] DATETIME       DEFAULT (getutcdate()) NOT NULL,
    [lastdiscovery]   DATETIME       DEFAULT (getutcdate()) NOT NULL,
    [servertype]      NVARCHAR (100) NULL,
    [serverlocation]  NVARCHAR (30)  NULL,
    [serverdecomdate] DATETIME       NULL,
    [environment]     NVARCHAR (10)  NULL,
    [servertypeid]    INT            NULL,
    PRIMARY KEY CLUSTERED ([serverid] ASC)
);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier for the server', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'serverid';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Name of the server', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'servername';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Date and time when the server was first discovered in the inventory', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'firstdiscovered';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Date and time of the last discovery/inventory scan for this server', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'lastdiscovery';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Type of server (e.g., Physical, Virtual, Cloud, etc.)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'servertype';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Physical location or data center of the server', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'serverlocation';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Date when the server was decommissioned (if applicable)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'serverdecomdate';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Environment where the server operates (Dev, QA, FST, Prod)', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'environment';
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Foreign key reference to core.servertype', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers', @level2type = N'COLUMN', @level2name = N'servertypeid';
GO

ALTER TABLE [core].[servers]
    ADD CONSTRAINT [CK_servers_environment] CHECK ([environment]='Prod' OR [environment]='FST' OR [environment]='QA' OR [environment]='Dev');
GO

ALTER TABLE [core].[servers]
    ADD CONSTRAINT [FK_servers_servertype] FOREIGN KEY ([servertypeid]) REFERENCES [core].[servertype] ([servertypeid]);
GO

GRANT INSERT
    ON OBJECT::[core].[servers] TO [PowerShellUser]
    AS [dbo];
GO

GRANT SELECT
    ON OBJECT::[core].[servers] TO [PowerShellUser]
    AS [dbo];
GO

CREATE NONCLUSTERED INDEX [IX_servers_servername_lastdiscovery]
    ON [core].[servers]([servername] ASC, [lastdiscovery] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_servers_servername]
    ON [core].[servers]([servername] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_servers_environment]
    ON [core].[servers]([environment] ASC);
GO

CREATE NONCLUSTERED INDEX [IX_servers_servertypeid]
    ON [core].[servers]([servertypeid] ASC);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Stores information about discovered servers in the inventory system', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servers';
GO

