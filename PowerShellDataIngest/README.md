# ASBDEM

## Overview
ASBDEM is a SQL Server inventory and logging database with a project-first deployment pipeline. The SQL project under `Database/` is the build source of truth, the DACPAC is generated from that project, and deployments are published with `sqlpackage` before the ingest scripts load discovery data.

## Quick Start
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM"
```

For a clean rebuild:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -DropDatabaseIfExists
```

See `DEPLOYMENT_GUIDE.md` for the full workflow and `Documentation\DACPAC-Guide.md` for DACPAC-specific usage.

## Deployment Flow
1. `PowerShellBuild\FullDeployment.ps1` checks SQL Server connectivity and creates the database when missing.
2. `PowerShellBuild\BuildDACPAC.ps1` builds `Database\InventoryDatabase.sqlproj` with `dotnet build`.
3. The generated DACPAC is published to the target database with `sqlpackage`.
4. `PowerShellDataIngest\RunDataIngest.ps1` loads server properties, configuration, and database inventory data.

## Source Of Truth
- `Database\ProjectModel\` contains the SQL objects used to build the DACPAC.
- `Database\Post-Deployment\Script.PostDeployment.sql` applies post-deployment grants.
- `Database\InventoryDatabase.sqlproj` packages the active project-first model.

## Legacy SQL Cleanup
Legacy hand-authored folders that previously sat alongside the SQL project have been removed.

See `Database\LEGACY-SOURCES.md` for the migration rationale and maintenance rule.

## Project Structure
```
Database/
├── InventoryDatabase.sqlproj
├── ProjectModel/              # Active SQL project source used for DACPAC builds
├── Post-Deployment/           # Post-deploy grants and deployment-only scripts
└── Tests/                     # SQL validation scripts

PowerShellBuild/               # Active deployment entrypoints
PowerShellDataIngest/          # Data collection and load scripts
Documentation/                # Deployment and DACPAC guides
```

## Prerequisites
- SQL Server 2019 or later
- .NET SDK 10 or later
- `sqlpackage` available on `PATH`
- PowerShell 5.1 or later
- Permissions to create, drop, and publish the target database
- Any PowerShell modules required by the ingest scripts, including `dbatools` in environments that use the shipped ingest scripts

## Validation
Build the SQL project directly:
```powershell
Set-Location D:\Repos\newASBDEMS
dotnet build .\Database\InventoryDatabase.sqlproj -c Release
```

Run the full deployment pipeline:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM"
```

## Troubleshooting
### Build fails
- Verify `.NET SDK 10+` is installed.
- Verify `Database\InventoryDatabase.sqlproj` and `Database\ProjectModel\` exist.
- Run `dotnet build .\Database\InventoryDatabase.sqlproj -c Release` from the repo root.

### Publish fails
- Verify `sqlpackage` is installed and on `PATH`.
- Verify the target server name and database permissions.
- Re-run `PowerShellBuild\BuildDACPAC.ps1 -Action Publish` with the same server and database parameters to isolate publish issues.

### Data ingest fails
- Verify the target database contains the published core and log objects.
- Verify connectivity from the host running `PowerShellDataIngest\RunDataIngest.ps1`.
- Review the per-step output from the ingest scripts for the failing source.
