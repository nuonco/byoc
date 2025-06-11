# Tenant Information
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

# Outputs that match the expected input names from the original implementation
output "auth_issuer_url" {
  description = "Auth0 Issuer URL (for auth_issuer_url input)"
  value       = "https://${var.auth0_domain}/"
}

output "auth_audience" {
  description = "Auth0 API audience identifier (for auth_audience input)"
  value       = auth0_resource_server.api.identifier
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

output "spa_application_name" {
  description = "The name of the created SPA application"
  value       = auth0_client.spa_application.name
}

# Match the expected input name for the Dashboard UI client ID
output "auth_client_id_dashboard_ui" {
  description = "Auth0 SPA Application client ID (for auth_client_id_dashboard_ui input)"
  value       = auth0_client.spa_application.client_id
}

# Native Application outputs
output "native_application_id" {
  description = "The ID of the Auth0 Native application"
  value       = auth0_client.native_application.client_id
}

output "native_application_secret" {
  description = "The client secret of the Auth0 Native application"
  value       = auth0_client.native_application.client_secret
  sensitive   = true
}

output "native_application_name" {
  description = "The name of the created Native application"
  value       = auth0_client.native_application.name
}

# Match the expected input name for the CTL API client ID
output "auth_client_id_ctl_api" {
  description = "Auth0 Native Application client ID (for auth_client_id_ctl_api input)"
  value       = auth0_client.native_application.client_id
}

# API Configuration
output "api_identifier" {
  description = "The unique identifier for the Auth0 API"
  value       = auth0_resource_server.api.identifier
}

# Database connection outputs
output "database_connection_id" {
  description = "The ID of the database connection"
  value       = auth0_connection.database.id
}

# Output all client configurations as a map for easy consumption
output "client_configs" {
  description = "Map of all client configurations"
  value = {
    spa = {
      client_id     = auth0_client.spa_application.client_id
      client_secret = auth0_client.spa_application.client_secret
      name          = auth0_client.spa_application.name
      type          = "spa"
    }
    native = {
      client_id     = auth0_client.native_application.client_id
      client_secret = auth0_client.native_application.client_secret
      name          = auth0_client.native_application.name
      type          = "native"
    }
  }
  sensitive = true
}

output "database_connection_name" {
  description = "The name of the database connection"
  value       = auth0_connection.database.name
}
