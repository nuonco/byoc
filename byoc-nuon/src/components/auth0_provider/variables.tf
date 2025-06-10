# Auth0 Provider Configuration
variable "auth0_domain" {
  type        = string
  description = "Your Auth0 domain (e.g., your-tenant.auth0.com)"
}

variable "auth0_client_id" {
  type        = string
  description = "Auth0 Management API Client ID"
  sensitive   = true
}

variable "auth0_client_secret" {
  type        = string
  description = "Auth0 Management API Client Secret"
  sensitive   = true
}

# Auth0 Tenant Configuration
variable "tenant_name" {
  type        = string
  description = "Friendly name for the Auth0 tenant"
}

variable "tenant_logo_url" {
  type        = string
  description = "URL to the tenant logo image"
  default     = ""
}

variable "support_email" {
  type        = string
  description = "Support email address for the tenant"
}

variable "support_url" {
  type        = string
  description = "Support URL for the tenant"
  default     = ""
}

variable "session_lifetime" {
  type        = number
  description = "Session lifetime in hours"
  default     = 72
}

# Nuon Variables (from Nuon context)
variable "install_name" {
  type        = string
  description = "Nuon installation name (from .nuon.install.name)"
  default     = "" # Will be populated from Nuon context
}

variable "install_id" {
  type        = string
  description = "Nuon installation ID (from .nuon.install.id)"
  default     = "" # Will be populated from Nuon context
}

variable "public_domain" {
  type        = string
  description = "Nuon public domain (from .nuon.install.public_domain)"
  default     = "" # Will be populated from Nuon context
}

variable "internal_domain" {
  type        = string
  description = "Nuon internal domain (from .nuon.install.internal_domain)"
  default     = "" # Will be populated from Nuon context
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
