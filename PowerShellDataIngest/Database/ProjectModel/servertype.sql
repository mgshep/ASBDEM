CREATE TABLE [core].[servertype] (
    [servertypeid]   INT            IDENTITY (1, 1) NOT NULL,
    [servertypename] NVARCHAR (100) NOT NULL,
    [description]    NVARCHAR (500) NULL,
    [isactive]       BIT            DEFAULT ((1)) NOT NULL,
    [createddate]    DATETIME       DEFAULT (getutcdate()) NOT NULL,
    PRIMARY KEY CLUSTERED ([servertypeid] ASC),
    UNIQUE NONCLUSTERED ([servertypename] ASC)
);


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Lookup table for server types', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servertype';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Description of the server type', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servertype', @level2type = N'COLUMN', @level2name = N'description';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Date when the server type was created', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servertype', @level2type = N'COLUMN', @level2name = N'createddate';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Name of the server type', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servertype', @level2type = N'COLUMN', @level2name = N'servertypename';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Indicates if the server type is active', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servertype', @level2type = N'COLUMN', @level2name = N'isactive';


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Unique identifier for server type', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'servertype', @level2type = N'COLUMN', @level2name = N'servertypeid';


GO

