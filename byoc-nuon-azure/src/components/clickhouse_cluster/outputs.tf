output "clickhouse_backups_bucket_id" {
  value = var.clickhouse_storage_container_name
}

output "clickhouse_backups_bucket" {
  value = {
    id                   = var.clickhouse_storage_container_name
    domain_name          = data.azurerm_storage_account.clickhouse_backups.primary_blob_host
    storage_account_name = var.clickhouse_storage_account_name
  }
}

output "service" {
  value = "clickhouse.clickhouse.svc.cluster.local"
}
