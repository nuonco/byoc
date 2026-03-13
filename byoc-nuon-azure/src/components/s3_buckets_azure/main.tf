resource "azurerm_storage_account" "this" {
  name                     = local.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "ZRS"

  local_user_enabled        = false
  shared_access_key_enabled = true

  tags = local.tags
}

resource "azurerm_storage_container" "install_templates" {
  name                  = "install-templates"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "clickhouse" {
  name                  = "clickhouse"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
