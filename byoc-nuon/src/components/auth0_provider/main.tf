terraform {
  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.21.0"
    }
  }
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_mgmt_client_id
  client_secret = var.auth0_mgmt_client_secret
}

# Define default URLs based on Nuon public_domain
locals {
  # Default callback URL for SPA application
  default_callback_url = "https://app.{{ .nuon.install.public_domain }}/api/auth/callback"

  # Default logout URL for SPA application
  default_logout_url = "https://app.{{ .nuon.install.public_domain }}"

  # Default web origin for SPA application
  default_web_origin = "https://app.{{ .nuon.install.public_domain }}"

  # Use provided callback_urls or default to the standard callback URL
  callback_urls = length(var.callback_urls) > 0 ? var.callback_urls : [local.default_callback_url]

  # Use provided logout_urls or default to the standard logout URL
  logout_urls = length(var.logout_urls) > 0 ? var.logout_urls : [local.default_logout_url]

  # Web origins for CORS - should be domain only without paths
  web_origins = length(var.web_origins) > 0 ? var.web_origins : [local.default_web_origin]
}

# SPA Application
resource "auth0_client" "spa_application" {
  name              = "${var.app_name}-spa"
  description       = "SPA Application"
  app_type          = "spa"
  oidc_conformant   = true
  cross_origin_auth = true

  callbacks           = local.callback_urls
  allowed_logout_urls = local.logout_urls
  web_origins         = local.web_origins
  allowed_origins     = local.web_origins

  jwt_configuration {
    alg = "RS256"
  }

  grant_types = [
    "authorization_code",
    "implicit",
    "refresh_token"
    # client_credentials removed - not compatible with SPA applications
  ]

  refresh_token {
    rotation_type   = "rotating"
    expiration_type = "expiring"
    token_lifetime  = 31557600 # 1 year (from README.md)
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
  name            = "${var.app_name}-native"
  description     = "Native Application"
  app_type        = "native"
  oidc_conformant = true

  # For native application, we don't need web origins or callbacks
  # as it will use the device code flow
  callbacks           = []
  allowed_logout_urls = []

  jwt_configuration {
    alg = "RS256"
  }

  grant_types = [
    "authorization_code",
    "refresh_token",
    "urn:ietf:params:oauth:grant-type:device_code"
  ]

  refresh_token {
    rotation_type   = "rotating"
    expiration_type = "expiring"
    token_lifetime  = 31557600 # 1 year
    leeway          = 0
  }

  # Security settings
  cross_origin_auth = true

  # Advanced settings
  sso = true
}

# Auth0 API resource for authentication (as specified in README)
resource "auth0_resource_server" "api" {
  name       = "API Gateway {{ .nuon.install.id }}"
  identifier = "https://api.{{ .nuon.install.public_domain }}"

  # Enable RBAC for the API
  enforce_policies = true
  token_lifetime   = 2592000
  token_dialect    = "access_token_authz"

  # Allow skipping user consent during authorization
  skip_consent_for_verifiable_first_party_clients = true

  # Allow offline access (refresh tokens)
  allow_offline_access = true
}
