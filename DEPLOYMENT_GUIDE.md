# ASBDEM Deployment Guide

## Overview
ASBDEM now deploys from the SQL project, not from a live database extract. The active pipeline builds a DACPAC from `Database\InventoryDatabase.sqlproj`, publishes that DACPAC to the target database, and then runs the ingest scripts to populate discovery data.

## Main Entry Point
Use `PowerShellBuild\FullDeployment.ps1` for end-to-end deployments.

The script performs these phases:
1. Preflight SQL Server connectivity and database existence checks.
2. Optional database drop and recreation.
3. DACPAC build from the SQL project.
4. DACPAC publish with `sqlpackage`.
5. Data ingest through `PowerShellDataIngest\RunDataIngest.ps1`.

## Typical Usage
From the `PowerShellBuild` folder:
```powershell
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM"
```

Fresh deployment:
```powershell
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -DropDatabaseIfExists
```

Custom project or DACPAC paths:
```powershell
.\FullDeployment.ps1 `
	-TargetServer "sqllaptop1\ni01" `
	-TargetDatabase "ASBDEM" `
	-ProjectPath "Database\InventoryDatabase.sqlproj" `
	-DacpacPath "Database\bin\Release\ASBDEM.dacpac"
```

## Helper Scripts
- `PowerShellBuild\BuildDACPAC.ps1`
	Builds the SQL project, publishes the generated DACPAC, or does both.
- `PowerShellBuild\Test-DatabaseDrift.ps1`
	Generates deploy and drift reports without changing the target database.
- `PowerShellDataIngest\RunDataIngest.ps1`
	Loads server properties, server configuration, and server database inventory.

## SQL Project Source Of Truth
The active build uses:
- `Database\ProjectModel\` for schema objects
- `Database\Post-Deployment\Script.PostDeployment.sql` for post-deploy grants
- `Database\InventoryDatabase.sqlproj` for packaging

Legacy side-by-side SQL folders have been removed. See `Database\LEGACY-SOURCES.md` for the maintenance rule.

## Build And Publish Separately
Build only:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\BuildDACPAC.ps1 -Action Build
```

Publish only:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\BuildDACPAC.ps1 -Action Publish -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -TrustServerCertificate
```

Build and publish in one call:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\BuildDACPAC.ps1 -Action BuildAndPublish -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -TrustServerCertificate
```

## Direct Project Validation
Validate the SQL project outside the wrapper scripts:
```powershell
Set-Location D:\Repos\newASBDEMS
dotnet build .\Database\InventoryDatabase.sqlproj -c Release
```

## Troubleshooting
### Build fails
- Verify `.NET SDK 10+` is installed.
- Verify `Database\InventoryDatabase.sqlproj` and `Database\ProjectModel\` exist.
- Run the direct `dotnet build` command from the repo root.

### Publish fails
- Verify `sqlpackage` is installed and available on `PATH`.
- Verify the login has permission to create or alter the target database.
- Re-run `BuildDACPAC.ps1 -Action Publish` directly to isolate publish issues from ingest issues.

### Database preflight fails
- Verify the SQL Server instance name is correct.
- Verify Windows authentication works with `sqlcmd -S <server> -d master -Q "SELECT @@SERVERNAME" -E`.
- Verify the caller can create and drop databases when `-DropDatabaseIfExists` is used.

### Data ingest fails
- Verify `PowerShellDataIngest\RunDataIngest.ps1` exists and the dependent modules are available.
- Verify the published database contains the required `core` and `log` objects.
- Review the step output for the failing ingest script.

## Recommended Workflow
1. Update SQL objects under `Database\ProjectModel\`.
2. Build the project with `dotnet build`.
3. Run `FullDeployment.ps1` against a development or test database.
4. Validate data and object creation with the SQL test scripts under `Database\Tests\`.
5. Promote the same project source to higher environments.
