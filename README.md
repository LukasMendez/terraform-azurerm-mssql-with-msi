# terraform-azurerm-mssql-with-msi
Azure SQL Database with Entra groups and MSI support. 

![alt text](/Diagram.jpg)

## Overview

This Terraform module facilitates the creation and management of Azure SQL Databases with dynamic security group configuration for any kind of role-based SQL access. It is designed to enable the use of Managed Identity for Azure services, automating the necessary steps to configure database access without requiring manual intervention post-deployment.

The module is split into two submodules to provide flexibility in managing role assignments:

1. **Database Creation with Role Assignment**: This module handles the creation of a new SQL database and assigns an initial role upon creation.
2. **Standalone Role Assignment**: This module allows for additional role assignments to be made to existing databases, enabling multiple role assignments as needed.

## Features

- **Managed Identity Support**: Automatically assigns the role specified in the `sql_role` variable (such as `db_reader`) to a specified Azure Entra group using Managed Identity, removing the need for manual post-deployment configuration. If none is specified, the script will default to `db_owner`
- **Flexible Database Creation**: Supports creating a new Azure SQL Database on either a new or an existing SQL server.
- **Database Cloning**: Offers the ability to clone an existing database, ideal for pre-production or testing environments that require a database identical to production.
- **Custom PowerShell Scripting**: Utilizes a custom PowerShell script to manage role assignments seamlessly within the module, as this is not yet supported by the official provider.
- **Integration with IaC Pipelines**: Supports specifying an access token for scenarios where the module is executed from an Infrastructure as Code (IaC) pipeline and the script cannot access the az token used in Terraform directly.
- **Multiple Role Assignments**: With the separate role assignment module, you can assign multiple roles to the same database, either during or after database creation.

## Prerequisites

- Terraform 0.XX.X or newer.
- An Azure subscription.
- PowerShell installed on the system executing the module.

## Usage

To use this module in your Terraform environment, configure the variables as per the module's requirements and include the module in your Terraform configurations.

## Module 1: Database Creation with Role Assignment

This module handles the creation of a new Azure SQL Database and assigns an initial role to a specified Entra group.

### Configuration Variables

- `environment`: Defines the subscription, and environment details.
- `sql_database`: Specifies the new SQL database's name, SKU, and optionally the source for cloning.
- `sql_database_entra_group`: Defines the name and members of the Azure Entra group for the database.
- `sql_server`: Configures the new SQL server's details, including admin credentials and IP allowlist.
- `sql_server_entra_group`: Specifies the Azure Entra group details for the SQL server.
- `external_sql_server`: When provided, the module will use the existing SQL server instead of creating a new one.
- `db_role`: Defines the SQL role that you want to assign to the service principal in the database. Default: `db_owner`
- `access_token`: When provided Terraform will use this access token in the PowerShell script for assigning permissions to the database

**Note**: For database cloning, ensure `copy_configuration` is provided under `sql_database`. If you plan to use an existing server, specify `external_sql_server` and leave `sql_server` and `sql_server_entra_group` empty.

### Example

```hcl
module "database" {
  source                      = "github.com/LukasMendez/terraform-azurerm-mssql-with-msi/modules/sql_database"
  environment                 = var.environment
  sql_database                = var.sql_database
  external_sql_server         = var.external_sql_server
  sql_database_entra_group    = {
    name    = var.sql_database_entra_group.name,
    members = data.azuread_group.database_owner_reference_group.members
  }
  db_role                     = "db_reader"
}

```

## Module 2: Standalone Role Assignment

This module is used to assign additional roles to an existing Azure SQL Database. This can be particularly useful if multiple Entra groups need access with different roles.

### Configuration Variables

- `sql_server_name`: Specifies the fully qualified domain name (FQDN) of the Azure SQL Server to which the role should be assigned.
- `sql_database_name`: Defines the name of the Azure SQL Database within the server where the role assignment will be made.
- `service_principal_name`: The name of the Azure service principal or Azure Entra group that will be assigned the specified SQL role.
- `tenant_id`: The Entra tenant ID that the service principal or Azure Entra group belongs to.
- `subscription_id`: Specifies the Azure subscription ID where the SQL Server and database are hosted.
- `sql_role`: Defines the SQL role that you want to assign to the service principal or Azure Entra group in the database. Default: `db_owner`.
- `access_token`: When provided, Terraform will use this access token in the PowerShell script for assigning permissions to the database. This is useful in scenarios where the module is executed from an Infrastructure as Code (IaC) pipeline and the script cannot access the Azure token used in Terraform directly.
- `depends_on`: A list of resource dependencies that ensures this module's operations occur after specific resources have been created.

### Example

```hcl
module "additional_role_assignment" {
  source                      = "github.com/LukasMendez/terraform-azurerm-mssql-with-msi/modules/sql_role_assignment"
  sql_server_name             = azurerm_mssql_server.global.fully_qualified_domain_name
  sql_database_name           = azurerm_mssql_database.global.name
  service_principal_name      = azuread_group.sql_database_readers.display_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  subscription_id             = var.environment.subscription_id
  sql_role                    = "db_reader"
  access_token                = var.access_token
  depends_on = [
    azurerm_mssql_database.global,
    azuread_group.sql_database_readers
  ]
}
```

## 
