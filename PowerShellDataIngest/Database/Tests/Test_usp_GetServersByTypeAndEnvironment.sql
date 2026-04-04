-- ============================================
-- Test: usp_GetServersByTypeAndEnvironment
-- Description: Tests various calling patterns
-- ============================================

-- Test 1: Get all servers (no filters)
PRINT '=== Test 1: Get All Servers (No Filters) ===';
EXEC [dbo].[usp_GetServersByTypeAndEnvironment];
PRINT '';

-- Test 2: Get servers by environment only (Dev)
PRINT '=== Test 2: Get Servers by Environment (Dev) ===';
EXEC [dbo].[usp_GetServersByTypeAndEnvironment] 
  @environment = 'Dev';
PRINT '';

-- Test 3: Get servers by environment (Prod)
PRINT '=== Test 3: Get Servers by Environment (Prod) ===';
EXEC [dbo].[usp_GetServersByTypeAndEnvironment] 
  @environment = 'Prod';
PRINT '';

-- Test 4: Get servers by server type name (Azure MI)
PRINT '=== Test 4: Get Servers by Type Name (Azure MI) ===';
EXEC [dbo].[usp_GetServersByTypeAndEnvironment] 
  @servertypename = 'Azure MI';
PRINT '';

-- Test 5: Get servers by both type name and environment
PRINT '=== Test 5: Get Servers by Type Name (Azure MI) AND Environment (Prod) ===';
EXEC [dbo].[usp_GetServersByTypeAndEnvironment] 
  @servertypename = 'Azure MI',
  @environment = 'Prod';
PRINT '';

-- Test 6: Get active server types only
PRINT '=== Test 6: Get All Servers with Active Types Only ===';
EXEC [dbo].[usp_GetServersByTypeAndEnvironment] 
  @isactive = 1;
PRINT '';

-- Test 7: Invalid environment value (should error)
PRINT '=== Test 7: Invalid Environment (Should Error) ===';
EXEC [dbo].[usp_GetServersByTypeAndEnvironment] 
  @environment = 'InvalidEnv';
PRINT '';
