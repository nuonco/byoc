# Auth0 Provider Configuration
variable "auth0_domain" {
  type        = string
  description = "Your Auth0 domain (e.g., your-tenant.auth0.com)"
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*\\.auth0\\.com$", var.auth0_domain))
    error_message = "The auth0_domain must be a valid Auth0 domain (e.g., your-tenant.auth0.com)"
  }
}

variable "auth0_client_id" {
  type        = string
  description = "Auth0 Management API Client ID"
  sensitive   = true
  validation {
    condition     = length(var.auth0_client_id) > 0
    error_message = "Auth0 client ID cannot be empty"
  }
}

variable "auth0_client_secret" {
  type        = string
  description = "Auth0 Management API Client Secret"
  sensitive   = true
  validation {
    condition     = length(var.auth0_client_secret) > 0
    error_message = "Auth0 client secret cannot be empty"
  }
}

# Application Configuration
variable "app_name" {
  type        = string
  description = "Name prefix for created Auth0 applications"
  default     = "nuon-app"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.app_name))
    error_message = "App name can only contain alphanumeric characters and hyphens"
  }
}

# Public domain is now defined in the Nuon variables section below

variable "callback_urls" {
  type        = list(string)
  description = "Allowed callback URLs for the applications"
  default     = []
  validation {
    condition     = alltrue([for url in var.callback_urls : can(regex("^https?://.*$", url))])
    error_message = "Callback URLs must be valid HTTP/HTTPS URLs"
  }
}

variable "default_callback_urls" {
  type        = list(string)
  description = "Default callback URLs based on public_domain"
  default     = []
  
  # This will be set in locals to avoid validation issues with computed values
}

variable "logout_urls" {
  type        = list(string)
  description = "Allowed logout URLs for the applications"
  default     = []
  validation {
    condition     = alltrue([for url in var.logout_urls : can(regex("^https?://.*$", url))])
    error_message = "Logout URLs must be valid HTTP/HTTPS URLs"
  }
}

variable "default_logout_urls" {
  type        = list(string)
  description = "Default logout URLs based on public_domain"
  default     = []
  
  # This will be set in locals to avoid validation issues with computed values
}

# Auth0 Tenant Configuration
variable "tenant_name" {
  type        = string
  description = "Friendly name for the Auth0 tenant"
  validation {
    condition     = length(var.tenant_name) > 0
    error_message = "Tenant name cannot be empty"
  }
}

variable "support_email" {
  type        = string
  description = "Support email address for the tenant"
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.support_email))
    error_message = "Please provide a valid email address for support"
  }
}


# Nuon Variables (from Nuon context)
# These use Nuon's built-in interpolations:
# - {{ .nuon.install.name }} - The name of the installation
# - {{ .nuon.install.id }} - The unique ID of the installation
# - {{ .nuon.install.public_domain }} - The public domain for the installation
# - {{ .nuon.install.internal_domain }} - The internal domain for the installation

# Note: These variables are automatically populated by Nuon at runtime
variable "install_name" {
  type        = string
  description = "Nuon installation name (populated by Nuon)"
  default     = "{{ .nuon.install.name }}"
}

variable "install_id" {
  type        = string
  description = "Nuon installation ID (populated by Nuon)"
  default     = "{{ .nuon.install.id }}"
}

variable "public_domain" {
  type        = string
  description = "Nuon public domain (populated by Nuon)"
  default     = "{{ .nuon.install.public_domain }}"
}

variable "internal_domain" {
  type        = string
  description = "Nuon internal domain (populated by Nuon)"
  default     = "{{ .nuon.install.internal_domain }}"
}

variable "issuer_url" {
  type        = string
  description = "The issuer URL for the Auth0 tenant"
  default     = "https://{{ .nuon.install.public_domain }}"
}

variable "org_id" {
  type        = string
  description = "Nuon organization ID (from .nuon.org.id)"
  default     = "" # Will be populated from Nuon context
}

variable "app_id" {
  type        = string
  description = "Nuon application ID (from .nuon.app.id)"
  default     = "" # Will be populated from Nuon context
}

# Auth0 Connection Configuration
variable "allow_signup" {
  type        = bool
  description = "Whether to allow users to sign up"
  default     = false
}
