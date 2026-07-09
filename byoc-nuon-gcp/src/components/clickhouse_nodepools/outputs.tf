output "node_service_account_email" {
  value = local.node_sa_email
}

output "installation_pool_name" {
  value = google_container_node_pool.clickhouse_installation.name
}

output "keeper_pool_name" {
  value = google_container_node_pool.clickhouse_keeper.name
}

# The nodeSelector/toleration key the ClickHouse CRD podTemplates pin against.
output "pool_key" {
  value = local.pool_key
}
