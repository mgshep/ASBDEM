# Legacy SQL Sources

## Status
The active DACPAC build no longer uses the older hand-authored SQL folders that previously existed in this directory tree.

The source of truth for current deployments is:
- `ProjectModel\`
- `Post-Deployment\`
- `InventoryDatabase.sqlproj`

## Maintenance Rule
When making new database changes:
1. Update objects under `ProjectModel\`.
2. Update post-deployment behavior under `Post-Deployment\` when needed.
3. Do not recreate legacy parallel source folders for deployable objects.

## Removed Folders
`Schema\` has been removed because its contents were superseded by `ProjectModel\` and are no longer needed for build, publish, or validation.

`StoredProcedures\` has also been removed because the active procedure definitions now live under `ProjectModel\`, and the manual deployment helper was updated to use that source.

`Security\` and `Scripts\` have also been removed because their deployable content was either superseded by `ProjectModel\` and `Post-Deployment\` or was no longer needed by the active project-first workflow.

Use Git history if earlier hand-authored versions are needed for comparison.