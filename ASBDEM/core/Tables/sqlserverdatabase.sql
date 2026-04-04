CREATE TABLE [core].[sqlserverdatabase] (
    [databaseid]             INT            IDENTITY (1, 1) NOT NULL,
    [serverid]               INT            NULL,
    [servername]             NVARCHAR (100) NULL,
    [instancename]           NVARCHAR (100) NULL,
    [databasename]           NVARCHAR (100) NULL,
    [owner]                  NVARCHAR (100) NULL,
    [createdate]             DATETIME       NULL,
    [recoverymodel]          NVARCHAR (50)  NULL,
    [status]                 NVARCHAR (50)  NULL,
    [compatibilitylevel]     INT            NULL,
    [collation]              NVARCHAR (100) NULL,
    [isonline]               BIT            NULL,
    [isuserdb]               BIT            NULL,
    [iswidelocalerestricted] BIT            NULL,
    [size_mb]                FLOAT (53)     NULL,
    [unallocatedspace_mb]    FLOAT (53)     NULL,
    [reserved_mb]            FLOAT (53)     NULL,
    [accessed]               DATETIME       NULL,
    [captured]               DATETIME       DEFAULT (getdate()) NULL,
    PRIMARY KEY CLUSTERED ([databaseid] ASC)
);
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Stores SQL Server database information and metadata', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'TABLE', @level1name = N'sqlserverdatabase';
GO

ALTER TABLE [core].[sqlserverdatabase]
    ADD CONSTRAINT [UK_sqlserverdatabase] UNIQUE NONCLUSTERED ([serverid] ASC, [databasename] ASC);
GO

