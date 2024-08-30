output "sql_database" {
    value = {
        id = azurerm_mssql_database.global.id
    }
}

output "sql_server" {
  value = length(azurerm_mssql_server.global) > 0 ? {
    id                         = azurerm_mssql_server.global[0].id
    fully_qualified_domain_name = azurerm_mssql_server.global[0].fully_qualified_domain_name
  } : null
}