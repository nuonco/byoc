locals {
  normalized_identifier = replace(lower(var.identifier), "/[^a-z0-9-]/", "-")
  trimmed_identifier    = trim(local.normalized_identifier, "-")
  server_name           = substr("pg-${local.trimmed_identifier}", 0, 63)
  allowed_storage_mb = [32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4193280, 4194304, 8388608, 16777216, 33553408]
  requested_mb       = tonumber(var.allocated_storage) * 1024
  storage_mb         = [for s in local.allowed_storage_mb : s if s >= local.requested_mb][0]
  tags = {
    "component-nuon-co-name" = "postgres-temporal"
    "install-nuon-co-id"     = var.nuon_id
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
