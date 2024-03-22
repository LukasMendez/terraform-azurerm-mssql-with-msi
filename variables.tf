variable "sql_database" {
  type = object({
    copy_configuration = optional(object({
        source_database_name = string,
        source_database_server_id = string
    }), null)
    name = string
    sku_name = optional(string, "S0")
    entra_admin_group = object({
        name = string,
        members = optional(list(string), [])
    })    
  })
}


variable "sql_server" {
  type = object({
    name = string,
    admin_name = string,
    resource_group_name = string,
    entra_admin_group = object({
        name = string,
        members = optional(list(string), [])
    })
    ip_allowlist = list(object({
      rule_name = string
      start_ip_address = string
      end_ip_address = string
    }))    
  })
  default = {
    ip_allowlist = []
  }  
}

# External SQL server, if none is specified, a new one will be created instead 
variable "external_sql_server" {
  type = object({
    name = string
    resource_group_name = string 
  })
  default = null
}

