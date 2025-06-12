# Tenant Information
# Note: tenant_id and tenant_name outputs have been removed as the auth0_tenant resource is not used
# The Management API does not allow creating tenants, only configuring existing ones

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

# Create client credentials for SPA application
resource "auth0_client_credentials" "spa_credentials" {
  client_id = auth0_client.spa_application.client_id
  authentication_method = "client_secret_post"
}

# SPA Application outputs
output "spa_application_id" {
  description = "The ID of the Auth0 SPA application"
  value       = auth0_client.spa_application.client_id
}

output "spa_application_name" {
  description = "The name of the created SPA application"
  value       = auth0_client.spa_application.name
}

output "spa_application_secret" {
  description = "The client secret of the Auth0 SPA application"
  value       = auth0_client_credentials.spa_credentials.client_secret
  sensitive   = true
}

# This output matches the original name expected by the rest of the application
output "auth0_client_secret" {
  description = "Auth0 SPA Application Client Secret (for compatibility with existing code)"
  value       = auth0_client_credentials.spa_credentials.client_secret
  sensitive   = true
}

# Match the expected input name for the Dashboard UI client ID
output "auth_client_id_dashboard_ui" {
  description = "Auth0 SPA Application client ID (for auth_client_id_dashboard_ui input)"
  value       = auth0_client.spa_application.client_id
}

# Native application does not use client credentials due to device code flow compatibility

# Native Application outputs
output "native_application_id" {
  description = "The ID of the Auth0 Native application"
  value       = auth0_client.native_application.client_id
}

output "native_application_name" {
  description = "The name of the created Native application"
  value       = auth0_client.native_application.name
}

# Native application does not have a client secret output as it uses device code flow

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

# Output all client configurations as a map for easy consumption
output "client_configs" {
  description = "Map of all client configurations"
  value = {
    spa = {
      client_id     = auth0_client.spa_application.client_id
      client_secret = auth0_client_credentials.spa_credentials.client_secret
      name          = auth0_client.spa_application.name
      type          = "spa"
    }
    native = {
      client_id     = auth0_client.native_application.client_id
      client_secret = null # Native app uses device code flow, no client secret
      name          = auth0_client.native_application.name
      type          = "native"
    }
  }
  sensitive = true
}
