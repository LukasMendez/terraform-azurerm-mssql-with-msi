# terraform-azurerm-mssql-with-msi
Azure SQL Database with Entra groups and MSI support. 

![alt text](/Diagram.jpg)

## Overview

This Terraform module facilitates the creation and management of Azure SQL Databases with dynamic security group configuration for any kind role-based SQL access. It is designed to enable the use of Managed Identity for Azure services, automating the necessary steps to configure database access without requiring manual intervention post-deployment.

## Features

- **Managed Identity Support**: Automatically assigns the role specified in the `sql_role` variable (such as `db_reader`) to a specified Azure Entra group using Managed Identity, removing the need for manual post-deployment configuration. If none is specified, the script will default to `db_owner`
- **Flexible Database Creation**: Supports creating a new Azure SQL Database on either a new or an existing SQL server.
- **Database Cloning**: Offers the ability to clone an existing database, ideal for pre-production or testing environments that require a database identical to production.
- **Custom PowerShell Scripting**: Utilizes a custom PowerShell script to manage role assignments seamlessly within the module, as this is not yet supported by the official provider.
- **Integration with IaC Pipelines**: Supports specifying an access token for scenarios where the module is executed from an Infrastructure as Code (IaC) pipeline and the script cannot access the az token used in Terraform directly.

## Prerequisites

- Terraform 0.XX.X or newer.
- An Azure subscription.
- PowerShell installed on the system executing the module.

## Usage

To use this module in your Terraform environment, configure the variables as per the module's requirements and include the module in your Terraform configurations.

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
    source                      = "github.com/LukasMendez/terraform-azurerm-mssql-with-msi"
    environment                 = var.environment
    sql_database                = var.sql_database
    external_sql_server         = var.external_sql_server
    sql_database_entra_group    = { 
        name = var.sql_database_entra_group.name, 
        members = data.azuread_group.database_owner_reference_group.members 
    }
    db_role                     = "db_reader"
}

