output "tenant_id" {
  description = "The ID of the Auth0 tenant"
  value       = auth0_tenant.tenant.id
}

output "tenant_name" {
  description = "The friendly name of the Auth0 tenant"
  value       = auth0_tenant.tenant.friendly_name
}

output "auth0_domain" {
  description = "The Auth0 domain"
  value       = var.auth0_domain
}

output "auth0_issuer_url" {
  description = "The Auth0 issuer URL"
  value       = "https://${var.auth0_domain}/"
}

# SPA Application outputs
output "spa_application_id" {
  description = "The ID of the Auth0 SPA application"
  value       = auth0_client.spa_application.client_id
}

output "spa_application_client_secret" {
  description = "The client secret of the Auth0 SPA application"
  value       = auth0_client.spa_application.client_secret
  sensitive   = true
}

# Native Application outputs
output "native_application_id" {
  description = "The ID of the Auth0 Native application"
  value       = auth0_client.native_application.client_id
}

output "native_application_client_secret" {
  description = "The client secret of the Auth0 Native application"
  value       = auth0_client.native_application.client_secret
  sensitive   = true
}

# Database connection outputs
output "database_connection_id" {
  description = "The ID of the database connection"
  value       = auth0_connection.database.id
}

output "database_connection_name" {
  description = "The name of the database connection"
  value       = auth0_connection.database.name
}
