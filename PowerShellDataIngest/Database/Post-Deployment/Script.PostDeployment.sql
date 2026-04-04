IF DATABASE_PRINCIPAL_ID(N'PowerShellUser') IS NOT NULL
BEGIN
    GRANT EXECUTE ON [core].[usp_UpsertServerProperty] TO [PowerShellUser];
    GRANT EXECUTE ON [core].[usp_UpsertServerConfig] TO [PowerShellUser];
    GRANT SELECT ON [core].[sqlserverProperties] TO [PowerShellUser];
    GRANT SELECT ON [core].[sqlserverConfig] TO [PowerShellUser];
    GRANT SELECT, INSERT ON [core].[servers] TO [PowerShellUser];
    GRANT EXECUTE ON [log].[usp_LogExecutionStart] TO [PowerShellUser];
    GRANT EXECUTE ON [log].[usp_LogExecutionEnd] TO [PowerShellUser];
    GRANT EXECUTE ON [log].[usp_LogActivity] TO [PowerShellUser];
    GRANT SELECT ON [log].[executionlog] TO [PowerShellUser];
    GRANT SELECT ON [log].[vw_ExecutionLog] TO [PowerShellUser];
END;