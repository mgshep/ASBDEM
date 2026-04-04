# ASBDEM Documentation Index

## Start Here
The active deployment model is project-first.

- Use `PowerShellBuild\FullDeployment.ps1` for end-to-end deployments.
- Use `PowerShellBuild\BuildDACPAC.ps1` for DACPAC-only build and publish operations.
- Use `PowerShellBuild\Test-DatabaseDrift.ps1` for non-destructive drift and deployment reports.

## Core Guides
- `..\DEPLOYMENT_GUIDE.md`
  End-to-end deployment workflow, usage examples, and troubleshooting.
- `DACPAC-Guide.md`
  SQL project build, DACPAC publish, and report generation details.
- `..\Database\LEGACY-SOURCES.md`
  Explanation of which SQL folders are archive-only and excluded from the SQL project.

## Source Of Truth
The active build source is:
- `..\Database\ProjectModel\`
- `..\Database\Post-Deployment\`
- `..\Database\InventoryDatabase.sqlproj`

The older side-by-side legacy SQL folders have been removed and are no longer part of the active DACPAC workflow.

## Quick Commands
Full deployment:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM"
```

Fresh deployment:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -DropDatabaseIfExists
```

Direct SQL project validation:
```powershell
Set-Location D:\Repos\newASBDEMS
dotnet build .\Database\InventoryDatabase.sqlproj -c Release
```
