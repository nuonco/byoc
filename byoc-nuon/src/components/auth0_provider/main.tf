terraform {
  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.0"
    }
  }
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
  
  # Note: The Auth0 provider will automatically handle retries and timeouts
  # with sensible defaults. No need to configure them explicitly.
}

# Define default URLs based on public_domain
locals {
  # Default callback URL for SPA application
  default_callback_url = "https://app.${var.public_domain}/api/auth/callback"
  
  # Default logout URL for SPA application
  default_logout_url = "https://app.${var.public_domain}"
  
  # Default web origin for SPA application
  default_web_origin = "https://app.${var.public_domain}"
  
  # Use provided callback_urls or default to the standard callback URL
  callback_urls = length(var.callback_urls) > 0 ? var.callback_urls : [local.default_callback_url]
  
  # Use provided logout_urls or default to the standard logout URL
  logout_urls = length(var.logout_urls) > 0 ? var.logout_urls : [local.default_logout_url]
  
  # Web origins for CORS
  web_origins = length(var.callback_urls) > 0 ? var.callback_urls : [local.default_web_origin]
}

# Auth0 Tenant Configuration
resource "auth0_tenant" "tenant" {
  friendly_name    = var.tenant_name
  support_email    = var.support_email
  session_lifetime = var.session_lifetime
  
  # Security settings
  allowed_logout_urls = local.logout_urls
  
  # Password policy - use the first callback URL as the default redirect
  default_redirection_uri = local.callback_urls[0]
  
  # Session settings
  session_cookie {
    mode = "persistent"
  }
}

# SPA Application
resource "auth0_client" "spa_application" {
  name                 = "${var.app_name}-spa"
  description          = "${var.tenant_name} - SPA Application"
  app_type             = "spa"
  oidc_conformant     = true
  cross_origin_auth   = true
  
  callbacks           = local.callback_urls
  allowed_logout_urls  = local.logout_urls
  web_origins         = local.web_origins
  allowed_origins     = local.web_origins
  
  jwt_configuration {
    alg = "RS256"
  }
  
  grant_types = [
    "authorization_code",
    "implicit",
    "refresh_token",
    "client_credentials"
  ]
  
  refresh_token {
    rotation_type    = "rotating"
    expiration_type  = "expiring"
    token_lifetime   = 31557600 # 1 year (from README.md)
    leeway          = 0
  }
  
  # Enable RBAC
  is_first_party = true
  
  # Security settings
  cross_origin_loc = "https://${var.auth0_domain}"
  
  # Advanced settings
  sso = true
}

# Native Application for the tenant (based on README.md)
resource "auth0_client" "native_application" {
  name                = "${var.app_name}-native"
  description         = "${var.tenant_name} - Native Application"
  app_type            = "native"
  oidc_conformant    = true
  
  # For native application, we don't need web origins or callbacks
  # as it will use the device code flow
  callbacks          = []
  allowed_logout_urls = []
  
  jwt_configuration {
    alg = "RS256"
  }
  
  grant_types = [
    "authorization_code",
    "refresh_token",
    "client_credentials"
  ]
  
  refresh_token {
    rotation_type    = "rotating"
    expiration_type  = "expiring"
    token_lifetime   = 31557600 # 1 year
    leeway          = 0
  }
  
  # Security settings
  cross_origin_auth = true
  
  # Advanced settings
  sso = true
}

# Database connection for username/password authentication
resource "auth0_connection" "database" {
  name           = "Username-Password-Authentication"
  display_name   = "Username-Password-Authentication"
  strategy       = "auth0"
  
  options {
    # Password policy settings
    password_policy = "excellent"
    
    # Password complexity options
    password_complexity_options {
      min_length = 12
    }
    
    # Password history
    password_history {
      enable = true
      size   = 5
    }
    
    # Dictionary settings
    password_dictionary {
      enable     = true
      dictionary = []
    }
    
    # Prevent personal info in passwords
    password_no_personal_info {
      enable = true
    }
    
    # Disable signups if not allowed
    disable_signup = !var.allow_signup
    
    # Brute force protection
    brute_force_protection = true
    
    # MFA settings
    mfa {
      active                 = true
      return_enroll_settings = true
    }
    
    # Disable import mode
    import_mode = false
    
    # Disable custom scripts
    custom_scripts = {}
    
    # Empty configuration
    configuration = {}
    
    # Enable username input
    requires_username = false
  }
  
  # Lifecycle settings to prevent configuration drift
  lifecycle {
    ignore_changes = [
      options[0].configuration
    ]
  }
}

# Associate the database connection with the SPA and native applications
resource "auth0_connection_clients" "database_clients" {
  connection_id = auth0_connection.database.id
  enabled_clients = [
    auth0_client.spa_application.client_id,
    auth0_client.native_application.client_id
  ]
  
  # Ensure the connection and clients are created first
  depends_on = [
    auth0_connection.database,
    auth0_client.spa_application,
    auth0_client.native_application
  ]
}
