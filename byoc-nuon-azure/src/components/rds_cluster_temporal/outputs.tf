output "endpoint" {
  value = "${azurerm_postgresql_flexible_server.this.fqdn}:${var.port}"
}

output "address" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "db_instance_master_user_secret_arn" {
  value = "inline://${azurerm_postgresql_flexible_server.this.id}"
}

output "db_instance_resource_id" {
  value = azurerm_postgresql_flexible_server.this.id
}

output "db_instance_port" {
  value = var.port
}

output "db_instance_name" {
  value = var.db_name
}

output "db_instance_username" {
  value = var.db_user
}

output "db_instance_availability_zone" {
  value = azurerm_postgresql_flexible_server.this.zone
}

output "db_instance_password" {
  value     = random_password.admin.result
  sensitive = true
}
