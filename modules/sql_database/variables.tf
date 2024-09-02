variable "environment" {
    type = object({
        subscription_id = string
        environment = string
        system = string
    })
}

variable "sql_database" {
  type = object({
    copy_configuration = optional(object({
        source_database_name = string,
        source_database_server = object({
          name = string
          resource_group_name = string
        })
    }), null)
    name = string
    sku_name = optional(string, "S0") 
  })
}

variable "sql_database_entra_group" {
  type = object({
      name = string,
      members = optional(list(string), [])
  })
}

variable "sql_server" {
  type = object({
    name = string,
    admin_name = string,
    resource_group_name = string,
    ip_allowlist = list(object({
      rule_name = string
      start_ip_address = string
      end_ip_address = string
    }))    
  })
  default = null
}

variable "sql_server_entra_group" {
  type = object({
      name = string,
      members = optional(list(string), [])
  })
  default = null
}

# External SQL server, if none is specified, a new one will be created instead 
variable "external_sql_server" {
  type = object({
    name = string
    resource_group_name = string 
  })
  default = null
}

variable "sql_role" {
  type = string
  default = "db_owner"
}

variable "access_token" {
  type = string
  default = ""
}

variable "dependencies" {
  type = any
  default = []    
}