CREATE TABLE [log].[sqlserverProperties] (
    [logid]        INT            IDENTITY (1, 1) NOT NULL,
    [serverid]     INT            NOT NULL,
    [servername]   NVARCHAR (100) NOT NULL,
    [instancename] NVARCHAR (100) NULL,
    [propertyname] NVARCHAR (200) NOT NULL,
    [action]       NVARCHAR (50)  NOT NULL,
    [property]     NVARCHAR (100) NULL,
    [oldvalue]     NVARCHAR (MAX) NULL,
    [newvalue]     NVARCHAR (MAX) NULL,
    [changedby]    NVARCHAR (128) DEFAULT (suser_sname()) NULL,
    [changeddate]  DATETIME       DEFAULT (getdate()) NOT NULL,
    PRIMARY KEY CLUSTERED ([logid] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_log_sqlserverProperties_servername_propertyname]
    ON [log].[sqlserverProperties]([servername] ASC, [propertyname] ASC, [changeddate] ASC);


GO

CREATE NONCLUSTERED INDEX [IX_log_sqlserverProperties_action]
    ON [log].[sqlserverProperties]([action] ASC, [changeddate] ASC);


GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Audit log for changes to server properties. Each property change is logged as a separate row with property column indicating the specific attribute (value, type).', @level0type = N'SCHEMA', @level0name = N'log', @level1type = N'TABLE', @level1name = N'sqlserverProperties';


GO

