
CREATE VIEW [core].[vw_ServerDetails]
AS
    SELECT
        s.serverid,
        s.servername,
        s.servertypeid,
        st.servertypename,
        st.description AS servertypedescription,
        s.environment,
        s.serverlocation,
        s.firstdiscovered,
        s.lastdiscovery,
        s.serverdecomdate,
        s.servertype AS legacyservertype,
        st.isactive AS servertypeisactive,
        st.createddate AS servertypecreateddate
    FROM [core].[servers] s
        LEFT JOIN [core].[servertype] st ON s.servertypeid = st.servertypeid;
GO

EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'View combining servers with their server type information from lookup table', @level0type = N'SCHEMA', @level0name = N'core', @level1type = N'VIEW', @level1name = N'vw_ServerDetails';
GO

