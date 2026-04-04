CREATE PROCEDURE [core].[usp_InsertServer]
    @servername NVARCHAR(100),
    @servertypeid INT = NULL,
    @serverlocation NVARCHAR(30) = NULL,
    @serverdecomdate DATETIME = NULL,
    @serverid INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @servername IS NULL OR LEN(LTRIM(@servername)) = 0
        BEGIN
            RAISERROR('Server name cannot be null or empty', 16, 1);
        END

        IF EXISTS (SELECT 1 FROM [core].[servers] WHERE servername = @servername)
        BEGIN
            UPDATE [core].[servers]
            SET
                lastdiscovery = GETUTCDATE(),
                servertypeid = ISNULL(@servertypeid, servertypeid),
                serverlocation = ISNULL(@serverlocation, serverlocation),
                serverdecomdate = ISNULL(@serverdecomdate, serverdecomdate)
            WHERE servername = @servername;

            SET @serverid = (SELECT serverid FROM [core].[servers] WHERE servername = @servername);
        END
        ELSE
        BEGIN
            INSERT INTO [core].[servers]
                (servername, servertypeid, serverlocation, serverdecomdate)
            VALUES
                (@servername, @servertypeid, @serverlocation, @serverdecomdate);

            SET @serverid = SCOPE_IDENTITY();
        END

        SELECT
            s.serverid AS ServerID,
            s.servername AS ServerName,
            s.firstdiscovered AS FirstDiscovered,
            s.lastdiscovery AS LastDiscovery,
            s.servertypeid AS ServerTypeID,
            st.servertypename AS ServerType,
            s.serverlocation AS ServerLocation,
            s.serverdecomdate AS ServerDecomDate
        FROM [core].[servers] s
        LEFT JOIN [core].[servertype] st ON s.servertypeid = st.servertypeid
        WHERE s.serverid = @serverid;
    END TRY
    BEGIN CATCH
        SELECT
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_SEVERITY() AS ErrorSeverity,
            ERROR_STATE() AS ErrorState,
            ERROR_PROCEDURE() AS ErrorProcedure,
            ERROR_LINE() AS ErrorLine,
            ERROR_MESSAGE() AS ErrorMessage;
    END CATCH
END
GO