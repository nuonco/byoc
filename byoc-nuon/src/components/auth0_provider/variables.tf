# Auth0 Provider Configuration
variable "auth0_domain" {
  type        = string
  description = "Your Auth0 domain (e.g., your-tenant.auth0.com)"
}

variable "auth0_mgmt_client_id" {
  type        = string
  description = "Auth0 Management API Client ID"
  sensitive   = true
  validation {
    condition     = length(var.auth0_mgmt_client_id) > 0
    error_message = "Auth0 Management API Client ID must be provided"
  }
}

variable "auth0_mgmt_client_secret" {
  type        = string
  description = "Auth0 Management API Client Secret"
  sensitive   = true
  validation {
    condition     = length(var.auth0_mgmt_client_secret) > 0
    error_message = "Auth0 Management API Client Secret must be provided"
  }
}

variable "install_name" {
  type        = string
  description = "Nuon installation name (populated by Nuon)"
}

variable "public_domain" {
  type        = string
  description = "Public domain for the installation"
}

variable "internal_domain" {
  type        = string
  description = "Internal domain for the installation"
}

variable "callback_url" {
  type        = string
  description = "The callback URL for the SPA application"
  validation {
    condition     = can(regex("^https?://.*$", var.callback_url))
    error_message = "Callback URL must be a valid HTTP/HTTPS URL"
  }
}

variable "logout_url" {
  type        = string
  description = "The logout URL for the SPA application"
  validation {
    condition     = can(regex("^https?://", var.logout_url))
    error_message = "Logout URL must start with http:// or https://"
  }
}

variable "web_origin" {
  type        = string
  description = "The web origin for CORS (domain only, no paths)"
  validation {
    condition     = can(regex("^https?://[^/]+$", var.web_origin))
    error_message = "Web origin must be a domain-only URL (no paths) starting with http:// or https://"
  }
}