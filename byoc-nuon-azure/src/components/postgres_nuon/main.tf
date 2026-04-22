locals {
  normalized_identifier = replace(lower(var.identifier), "/[^a-z0-9-]/", "-")
  trimmed_identifier    = trim(local.normalized_identifier, "-")
  server_name           = substr("pg-${local.trimmed_identifier}", 0, 63)
  storage_mb            = max(32768, tonumber(var.allocated_storage) * 1024)
  tags = {
    "component.nuon.co/name" = "postgres-cluster"
    "install.nuon.co/id"     = var.nuon_id
  }
}

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                   = local.server_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = "16"
  administrator_login    = var.db_user
  administrator_password = random_password.admin.result
  sku_name               = var.instance_class
  storage_mb             = local.storage_mb
  backup_retention_days  = tonumber(var.backup_retention_period)
  zone                   = var.zone

  public_network_access_enabled = true

  tags = local.tags
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
