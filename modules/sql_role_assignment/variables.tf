variable "sql_server_name" {
    type = string
}

variable "sql_database_name" {
    type = string
}

variable "service_principal_name" {
    type = string
}

variable "tenant_id" {
    type = string
}

variable "subscription_id" {
    type = string
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
  type = list(any)
  default = []    
}