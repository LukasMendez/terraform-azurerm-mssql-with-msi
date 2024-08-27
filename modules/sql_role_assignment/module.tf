resource "null_resource" "sql_role_assignment" {
  provisioner "local-exec" {
  command = "Set-ExecutionPolicy Bypass -Scope Process -Force; & './${path.module}/scripts/sql_role_assignment.ps1' '${var.sql_server_name}' '${var.sql_database_name}' '${var.service_principal_name}' '${var.tenant_id}' '${var.subscription_id}' '${var.sql_role}' '${var.access_token}'"

    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = var.dependencies

}