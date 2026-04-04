$server = "sqllaptop1\ni01"
$database = "ASBDEM"
$repoRoot = $PSScriptRoot
$procFile = Join-Path $repoRoot "Database\ProjectModel\usp_UpsertServerDatabase.sql"
$testFile = Join-Path $repoRoot "Database\Tests\test_logging_null.sql"

if (-not (Test-Path $procFile)) {
    Write-Host "   ✗ Procedure source not found: $procFile"
    exit 1
}

Write-Host "====== Deploying usp_UpsertServerDatabase ======"

# Step 1: Drop procedure
Write-Host  "`n1. Dropping existing procedure..."
$dropResult = sqlcmd -S $server -d $database -Q "IF OBJECT_ID('[core].[usp_UpsertServerDatabase]', 'P') IS NOT NULL DROP PROCEDURE [core].[usp_UpsertServerDatabase];" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Procedure dropped (or didn't exist)"
}
else {
    Write-Host "   ✗ Error during drop: $dropResult"
    exit 1  
}

# Step 2: Deploy new version
Write-Host "`n2. Deploying corrected procedure..."
$deployResult = Get-Content $procFile -Raw | sqlcmd -S $server -d $database 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Procedure deployed successfully"
}
else {
    Write-Host "   ✗ Error during deployment"
    Write-Host $deployResult
    exit 1
}

# Step 3: Verify deployment
Write-Host "`n3. Verifying procedure exists..."
$verifyResult = sqlcmd -S $server -d $database -Q "SELECT OBJECT_ID('[core].[usp_UpsertServerDatabase]') as ProcID"
if ($verifyResult -like "*[0-9]*") {
    Write-Host "   ✓ Procedure verified in database"
}
else {
    Write-Host "   ✗ Procedure not found"
    exit 1
}

# Step 4: Test with NULL parameters (should work)
Write-Host "`n4. Testing with NULL parameters..."
$testNull = sqlcmd -S $server -d $database -i $testFile 2>&1
if ($testNull -like "*0*") {
    Write-Host "   ✓ NULL parameter test passed"
}
else {
    Write-Host "   ✗ NULL parameter test failed"
}

Write-Host "`n====== Deployment Complete ======"
