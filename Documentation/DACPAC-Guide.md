# ASBDEM DACPAC Guide

## Overview
The ASBDEM DACPAC is now built from the SQL project, not extracted from a live database. The active source is `Database\ProjectModel\`, the SQL project is `Database\InventoryDatabase.sqlproj`, and the helper script is `PowerShellBuild\BuildDACPAC.ps1`.

## Current Build Model
1. SQL objects are maintained under `Database\ProjectModel\`.
2. `dotnet build` packages `Database\InventoryDatabase.sqlproj` into a DACPAC.
3. `sqlpackage` publishes that DACPAC to the target database.
4. `Database\Post-Deployment\Script.PostDeployment.sql` applies post-deploy grants.

The older side-by-side legacy SQL folders have been removed. The active DACPAC build comes entirely from `Database\ProjectModel\` plus `Database\Post-Deployment\`.

## Build Commands
Build the project directly:
```powershell
Set-Location D:\Repos\newASBDEMS
dotnet build .\Database\InventoryDatabase.sqlproj -c Release
```

Build through the wrapper script:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\BuildDACPAC.ps1 -Action Build
```

The default output path is:
```text
Database\bin\Release\ASBDEM.dacpac
```

## BuildDACPAC.ps1 Actions
### Build
```powershell
.\BuildDACPAC.ps1 -Action Build
```
Builds the SQL project and copies the newest DACPAC to `Database\bin\Release\ASBDEM.dacpac`.

### Publish
```powershell
.\BuildDACPAC.ps1 -Action Publish -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -TrustServerCertificate
```
Publishes an existing DACPAC to the target database.

### BuildAndPublish
```powershell
.\BuildDACPAC.ps1 -Action BuildAndPublish -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -TrustServerCertificate
```
Builds the project first and then publishes the generated DACPAC.

## Full Deployment
For the full database lifecycle, use:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM"
```

Fresh deployment with drop-and-recreate:
```powershell
.\FullDeployment.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -DropDatabaseIfExists
```

## SqlPackage Examples
Publish the generated DACPAC directly:
```powershell
sqlpackage /Action:Publish `
  /SourceFile:D:\Repos\newASBDEMS\Database\bin\Release\ASBDEM.dacpac `
  /TargetServerName:"sqllaptop1\ni01" `
  /TargetDatabaseName:"ASBDEM" `
  /TargetTrustServerCertificate:True `
  /p:RegisterDataTierApplication=False
```

Generate a deployment script without applying changes:
```powershell
sqlpackage /Action:Script `
  /SourceFile:D:\Repos\newASBDEMS\Database\bin\Release\ASBDEM.dacpac `
  /TargetServerName:"sqllaptop1\ni01" `
  /TargetDatabaseName:"ASBDEM" `
  /TargetTrustServerCertificate:True `
  /OutputPath:D:\Repos\newASBDEMS\deployment-script.sql
```

Generate a drift or deployment report with the provided helper:
```powershell
Set-Location D:\Repos\newASBDEMS\PowerShellBuild
.\Test-DatabaseDrift.ps1 -TargetServer "sqllaptop1\ni01" -TargetDatabase "ASBDEM" -DacpacPath "Database\bin\Release\ASBDEM.dacpac" -Mode Both -TrustServerCertificate
```

## Version Control Guidance
- Commit `Database\InventoryDatabase.sqlproj`.
- Commit SQL source under `Database\ProjectModel\` and `Database\Post-Deployment\`.
- Treat the DACPAC as a generated artifact. Commit it only when you intentionally want a release artifact in source control.

## Validation Status
The SQL project can be validated directly with:
```powershell
dotnet build .\Database\InventoryDatabase.sqlproj -c Release
```

## Troubleshooting
### Build fails
- Verify `.NET SDK 10+` is installed.
- Verify `Database\InventoryDatabase.sqlproj` exists.
- Verify the object files under `Database\ProjectModel\` are present.

### Publish fails
- Verify `sqlpackage` is installed and on `PATH`.
- Verify the target login can create or alter the database.
- Verify the DACPAC path exists before publish.

### Need to review changes before publish
Use `sqlpackage /Action:Script` or `PowerShellBuild\Test-DatabaseDrift.ps1` instead of publishing directly.

## Resources

- [SqlPackage Documentation](https://learn.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage)
- [DACPAC Overview](https://learn.microsoft.com/en-us/sql/relational-databases/data-tier-applications/data-tier-applications)
- [MSBuild.Sdk.SqlProj](https://www.nuget.org/packages/MSBuild.Sdk.SqlProj/)
- [Microsoft.SqlServer.Dacpacs.Master](https://www.nuget.org/packages/Microsoft.SqlServer.Dacpacs.Master/)
