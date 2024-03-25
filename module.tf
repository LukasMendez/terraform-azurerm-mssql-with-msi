locals {
  common_tags = {
      Environment = var.environment.environment
      System      = var.environment.system
      Source      = "Terraform"
  }
  create_sql_server = var.external_sql_server == null ? true : false

  # Used to decide what name should be used based on whether we are using our own SQL server or an external one
  sql_server_name = local.create_sql_server == true ? azurerm_mssql_server.global[0].name : data.azurerm_mssql_server.external[0].name  

    # Used to decide if we are making a copy of a database
  create_database_copy = var.sql_database.copy_configuration != null ? true : false

  // IP allowlist which is only used when we create the SQL server ourselves
  conditional_ip_allowlist = local.create_sql_server ? tomap({ for ip_rule in var.sql_server.ip_allowlist : ip_rule.rule_name => ip_rule }) : {}
}

# Gets information about the user who is currently signed in with az login 
# Can be used to assign yourself to resources easily 
data "azurerm_client_config" "current" {}

# The module expects a resource group to be created upfront 
data "azurerm_resource_group" "sql_server" {
  name = local.create_sql_server == true ? var.sql_server.resource_group_name : var.external_sql_server.resource_group_name
}

# Only relevant if we are creating a copy of an existing source database
data "azurerm_mssql_server" "source_copy_server" {
  count = local.create_database_copy == true ? 1 : 0
  
  name                = var.sql_database.copy_configuration.source_database_server.name
  resource_group_name = var.sql_database.copy_configuration.source_database_server.resource_group_name
}

# Only relevant if we are creating a copy of an existing source database
data "azurerm_mssql_database" "source_copy_database" {
    count = local.create_database_copy == true ? 1 : 0

    name = var.sql_database.copy_configuration.source_database_name
    server_id = data.azurerm_mssql_server.source_copy_server[0].id
}

resource "azurerm_mssql_database" "global" {
  name           = var.sql_database.name

  # Assign the server based on whether it should be created or fetched externally
  server_id      = local.create_sql_server == true ? azurerm_mssql_server.global[0].id : data.azurerm_mssql_server.external[0].id
  sku_name       = var.sql_database.sku_name

  # The following parameters are only used if we are copying from another database
  create_mode                 = local.create_database_copy == true ? "Copy" : "Default"
  creation_source_database_id = local.create_database_copy == true ? data.azurerm_mssql_database.source_copy_database[0].id : null

  tags = local.common_tags
}


data "azurerm_mssql_server" "external" {
  # The following will ignore the data source if no existing resource group has been specified
  # That way we can assume that an SQL server should be created instead
  count = local.create_sql_server == false ? 1 : 0

  name                = var.external_sql_server.name
  resource_group_name = data.azurerm_resource_group.sql_server.name
}

# The following resource is only created when we haven't specified any external SQL server
resource "azurerm_mssql_server" "global" {
  count = local.create_sql_server == true ? 1 : 0

  name                         = var.sql_server.name
  resource_group_name          = data.azurerm_resource_group.sql_server.name
  location                     = data.azurerm_resource_group.sql_server.location
  version                      = "12.0"
  minimum_tls_version          = "1.2"

  azuread_administrator {
    login_username = var.sql_server.admin_name
    object_id      = azuread_group.sql_server_admins[0].object_id
    azuread_authentication_only = true
  }

  identity{
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_mssql_firewall_rule" "global_clients" {
  for_each         = local.conditional_ip_allowlist

  name             = each.value.rule_name
  server_id        = azurerm_mssql_server.global[0].id
  start_ip_address = each.value.start_ip_address
  end_ip_address   = each.value.end_ip_address
}

# Allow access to Azure services
resource "azurerm_mssql_firewall_rule" "global_azure_interally" {
  count            = local.create_sql_server == true ? 1 : 0

  name             = "Azure resources"
  server_id        = azurerm_mssql_server.global[0].id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Entra 

resource "azuread_group" "sql_server_admins" {
  # Create an admin group only if we are creating the SQL server ourselves
  count = local.create_sql_server == true ? 1 : 0

  display_name     = var.sql_server_entra_group.name
  owners           = [data.azurerm_client_config.current.object_id]
  security_enabled = true
  
  members = concat(
    [data.azurerm_client_config.current.object_id], 
    var.sql_server_entra_group.members
  )

  lifecycle {
    # Do not try to revert changes on members
    ignore_changes = [owners, members]
  }
}

resource "azuread_group" "sql_database_admins" {
  display_name     = var.sql_database_entra_group.name
  owners           = [data.azurerm_client_config.current.object_id]
  security_enabled = true
  
  members = concat(
    [data.azurerm_client_config.current.object_id], 
    var.sql_database_entra_group.members
  )

  lifecycle {
    # Do not try to revert changes on members
    ignore_changes = [owners, members]
  }
}

resource "null_resource" "sql_role_assignment" {
  provisioner "local-exec" {
  command = "Set-ExecutionPolicy Bypass -Scope Process -Force; & './${path.module}/scripts/sql_role_assignment.ps1' '${local.create_sql_server == true ? azurerm_mssql_server.global[0].fully_qualified_domain_name : data.azurerm_mssql_server.external[0].fully_qualified_domain_name}' '${azurerm_mssql_database.global.name}' '${azuread_group.sql_database_admins.display_name}' '${data.azurerm_client_config.current.tenant_id}' '${var.environment.subscription_id}' '${var.environment.access_token}'"

    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [
    azurerm_mssql_database.global,
    azuread_group.sql_database_admins
  ]
}
