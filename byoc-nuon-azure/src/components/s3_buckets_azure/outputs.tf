output "install_template_bucket" {
  value = {
    id                   = azurerm_storage_container.install_templates.name
    arn                  = ""
    domain_name          = azurerm_storage_account.this.primary_blob_host
    base_url             = "https://${azurerm_storage_account.this.primary_blob_host}/${azurerm_storage_container.install_templates.name}/"
    region               = var.location
    storage_account_id   = azurerm_storage_account.this.id
    storage_account_name = azurerm_storage_account.this.name
    container_id         = azurerm_storage_container.install_templates.id
  }
}

output "clickhouse_bucket" {
  value = {
    id                   = azurerm_storage_container.clickhouse.name
    arn                  = ""
    domain_name          = azurerm_storage_account.this.primary_blob_host
    storage_account_id   = azurerm_storage_account.this.id
    storage_account_name = azurerm_storage_account.this.name
    container_id         = azurerm_storage_container.clickhouse.id
  }
}

output "clickhouse_bucket_role" {
  value = {
    arn = ""
  }
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "install_templates_container_name" {
  value = azurerm_storage_container.install_templates.name
}
