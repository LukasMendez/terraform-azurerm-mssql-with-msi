param (
    [string]$sqlServerName,
    [string]$sqlDatabaseName,
    [string]$servicePrincipalName,
    [string]$tenantId,
    [string]$subscriptionId,
    [string]$dbRole = "db_owner",    
    [string]$accessToken = ""
)

# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

Write-Output "Is running 64 bit?"
[Environment]::Is64BitProcess

$modulesToInstall = @()

# Check if all dependencies are installed, and if not install them
if (-not(Get-InstalledModule -Name Az -ErrorAction SilentlyContinue)) {
  Write-Output "Az Module not installed. Will install before proceeding"
  $modulesToInstall += 'Az'
}

if (-not(Get-InstalledModule -Name SqlServer -ErrorAction SilentlyContinue)) {
  $modulesToInstall += 'SqlServer'
  Write-Output "SqlServer Module not installed. Will install before proceeding"
}

if ($modulesToInstall.Count -gt 0) {
  Write-Output "Installing missing dependencies"
  Install-Module -Name $modulesToInstall -Force -AllowClobber
}


# Import the Az module
Import-Module -Name Az -Force
Import-Module -Name SqlServer -Force


# Check if the variables are null or empty
if (([string]::IsNullOrEmpty($sqlServerName))) {
    Throw "sqlServerName variable is null or empty."
}
if (([string]::IsNullOrEmpty($sqlDatabaseName))) {
    Throw "sqlDatabaseName variable is null or empty."
}
if (([string]::IsNullOrEmpty($servicePrincipalName))) {
    Throw "servicePrincipalName variable is null or empty."
}
if (([string]::IsNullOrEmpty($tenantId))) {
    Throw "tenantId variable is null or empty."
}
if (([string]::IsNullOrEmpty($subscriptionId))) {
    Throw "subscriptionId variable is null or empty."
}

Set-AzContext -Subscription $subscriptionId 

$defaultSchema = 'dbo'

# If no optional token was provided upfront, try to get a new one
if (([string]::IsNullOrEmpty($accessToken))) {
    $accessToken = (az account get-access-token --resource https://database.windows.net | ConvertFrom-Json).accessToken
}

# Ensure that even if the dbRole is overwritten we will still use db_owner at default if new provided value is empty
if (([string]::IsNullOrEmpty($dbRole))) {
    $dbRole = 'db_owner'
}

# Check if the user already exists
$userExists = (Invoke-Sqlcmd -ServerInstance $sqlServerName -Database $sqlDatabaseName -AccessToken $accessToken -Query "SELECT name FROM sys.database_principals WHERE name = '$servicePrincipalName'" -Verbose) 

# If the user does not exist, create the user and add it to the db_owner role
if (!$userExists) {
    Write-Output "User $servicePrincipalName does not exists already. Creating user in the database."
    $createUserSqlQuery = "CREATE USER [$servicePrincipalName] FROM EXTERNAL PROVIDER WITH DEFAULT_SCHEMA = [$defaultSchema]; ALTER ROLE $dbRole ADD MEMBER [$servicePrincipalName];"
    Invoke-Sqlcmd -ServerInstance $sqlServerName -Database $sqlDatabaseName -AccessToken $accessToken -Query $createUserSqlQuery
    Write-Output "User $servicePrincipalName created and added to $dbRole role."
} else {
    Write-Output "User $servicePrincipalName already exists."
}

$userExists = (Invoke-Sqlcmd -ServerInstance $sqlServerName -Database $sqlDatabaseName -AccessToken $accessToken -Query "SELECT name FROM sys.database_principals WHERE name = '$servicePrincipalName'")
if(!$userExists){
    Throw "User could not be created"
}