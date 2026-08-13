output "cluster_name" {
  description = "Name of the Strimzi Kafka CR"
  value       = local.cluster
}

output "namespace" {
  description = "Namespace the Kafka cluster runs in"
  value       = local.namespace
}

# Deterministic, so ctl-api hardcodes this in values/ctl-api.yaml rather than taking
# a dependency on this component's outputs.
output "bootstrap_servers" {
  description = "Bootstrap address for the internal TLS listener"
  value       = local.bootstrap_servers
}

output "cluster_ca_secret" {
  description = "Secret holding the CA cert clients use to verify brokers"
  value       = local.cluster_ca_secret
}

output "client_user_secret" {
  description = "Secret holding ctl-api's mTLS cert and key"
  value       = local.kafka_user
}

output "topics" {
  description = "Topic names managed by this component"
  value       = local.topics
}

# Deterministic like bootstrap_servers, so dashboard-ui hardcodes it in its values
# (NUON_KAFKA_UI_URL) rather than taking a dependency on this component.
output "kafka_ui_url" {
  description = "In-cluster address of the kafbat UI, proxied by dashboard-ui at /admin/kafka"
  value       = "http://${local.kafka_ui}.${local.namespace}.svc.cluster.local:${local.kafka_ui_port}"
}
