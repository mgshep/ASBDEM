[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SqlInstance = "sqllaptop1\ni01",

    [Parameter(Mandatory = $false)]
    [string]$Database = "ASBDEM"
)

$implementationPath = Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath 'Get-SQLServerConfig.ps1'

if (-not (Test-Path -Path $implementationPath)) {
    throw "Implementation script not found at '$implementationPath'."
}

& $implementationPath -SqlInstance $SqlInstance -Database $Database