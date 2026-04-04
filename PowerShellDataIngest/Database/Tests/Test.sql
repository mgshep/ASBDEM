-- ============================================================================
-- ASBDEM Database Test Script
-- ============================================================================
-- This script validates the ASBDEM database setup and schema creation
-- ============================================================================

USE [ASBDEM]
GO

PRINT '========================================='
PRINT 'ASBDEM Database Validation Tests'
PRINT '========================================='
PRINT ''

-- Test 1: Verify database exists
PRINT 'Test 1: Verify ASBDEM database exists'
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'ASBDEM')
    PRINT 'PASS: ASBDEM database created'
ELSE
BEGIN
    PRINT 'FAIL: ASBDEM database not found'
    GOTO TEST_FAILED
END
PRINT ''

-- Test 2: Verify core schema exists
PRINT 'Test 2: Verify core schema exists'
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'core')
    PRINT 'PASS: core schema created'
ELSE
BEGIN
    PRINT 'FAIL: core schema not found'
    GOTO TEST_FAILED
END
PRINT ''

-- Test 3: Verify auto schema exists
PRINT 'Test 3: Verify auto schema exists'
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'auto')
    PRINT 'PASS: auto schema created'
ELSE
BEGIN
    PRINT 'FAIL: auto schema not found'
    GOTO TEST_FAILED
END
PRINT ''

-- Test 4: Verify rpt schema exists
PRINT 'Test 4: Verify rpt schema exists'
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'rpt')
    PRINT 'PASS: rpt schema created'
ELSE
BEGIN
    PRINT 'FAIL: rpt schema not found'
    GOTO TEST_FAILED
END
PRINT ''

-- Test 5: Verify log schema exists
PRINT 'Test 5: Verify log schema exists'
IF EXISTS (SELECT * FROM sys.schemas WHERE name = 'log')
    PRINT 'PASS: log schema created'
ELSE
BEGIN
    PRINT 'FAIL: log schema not found'
    GOTO TEST_FAILED
END
PRINT ''

-- Test 6: List all schemas
PRINT 'Test 6: Summary of all schemas in ASBDEM'
SELECT 
    s.schema_id,
    s.name as SchemaName,
    p.name as OwnerName
FROM 
    sys.schemas s
    LEFT JOIN sys.database_principals p ON s.principal_id = p.principal_id
WHERE 
    s.name IN ('core', 'auto', 'rpt', 'log')
ORDER BY 
    s.name
PRINT ''

-- Test 7: Database configuration check
PRINT 'Test 7: Database configuration'
SELECT
    name,
    recovery_model_desc,
    compatibility_level,
    is_read_committed_snapshot_on
FROM 
    sys.databases
WHERE 
    name = 'ASBDEM'
PRINT ''

PRINT '========================================='
PRINT 'All Tests Passed Successfully!'
PRINT '========================================='
GOTO TEST_COMPLETE

TEST_FAILED:
PRINT '========================================='
PRINT 'Tests Failed!'
PRINT '========================================='

TEST_COMPLETE:
GO
