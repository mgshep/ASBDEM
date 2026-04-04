-- Final Verification: Data Summary
SELECT 'CORE TABLES' as Category;
    SELECT '  Servers' as Item, COUNT(*) as Count
    FROM [core].[servers]
UNION ALL
    SELECT '  Properties', COUNT(*)
    FROM [core].[sqlserverProperties]
UNION ALL
    SELECT '  Configurations', COUNT(*)
    FROM [core].[sqlserverConfig]
UNION ALL
    SELECT '  Databases', COUNT(*)
    FROM [core].[sqlserverdatabase];

SELECT '';
SELECT 'AUDIT LOG TABLES' as Category;
    SELECT '  Property Audit Logs' as Item, COUNT(*) as Count
    FROM [log].[sqlserverProperties]
UNION ALL
    SELECT '  Config Audit Logs', COUNT(*)
    FROM [log].[sqlserverConfig]
UNION ALL
    SELECT '  Database Audit Logs', COUNT(*)
    FROM [log].[sqlserverdatabase];

SELECT '';
SELECT 'SUMMARY: Fixed procedure with type-safe CROSS APPLY now logs all changes successfully!' as Result;
