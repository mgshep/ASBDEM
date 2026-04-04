-- Test minimal MERGE with datetime output
DECLARE @now DATETIME = GETDATE();

-- Create test table if needed
IF OBJECT_ID('test_merge_output', 'U') IS NULL
BEGIN
    CREATE TABLE test_merge_output
    (
        id INT PRIMARY KEY,
        name NVARCHAR(100),
        accessed DATETIME
    );
END

-- Test simple MERGE OUTPUT with datetime
DECLARE @MergeOut TABLE (
    Action NVARCHAR(10),
    ID INT,
    Name NVARCHAR(100),
    OldAccessed NVARCHAR(100),
    NewAccessed NVARCHAR(100)
);

MERGE INTO test_merge_output AS target
USING (SELECT 1 as id, N'Test' as name, @now as accessed) AS source
    ON target.id = source.id
WHEN NOT MATCHED THEN
    INSERT (id, name, accessed) VALUES (source.id, source.name, source.accessed)
OUTPUT 
    $action,
    inserted.id,
    inserted.name,
    CAST(ISNULL(CONVERT(NVARCHAR(100), deleted.accessed), '') AS NVARCHAR(100)),
    CAST(ISNULL(CONVERT(NVARCHAR(100), inserted.accessed), '') AS NVARCHAR(100))
INTO @MergeOut;

SELECT 'Merge completed' as Result;
SELECT *
FROM @MergeOut;
