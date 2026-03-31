output "network_self_link" {
  value       = var.network_id
  description = "The VPC network self_link, passed through for downstream components."
}

output "peering_range" {
  value       = google_compute_global_address.private_services.name
  description = "The reserved peering range name."
}
