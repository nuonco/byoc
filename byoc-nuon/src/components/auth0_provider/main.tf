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

# SPA Application
resource "auth0_client" "spa_application" {
  name              = "${var.install_name}-spa"
  description       = "SPA Application"
  app_type          = "spa"
  oidc_conformant   = true
  cross_origin_auth = true

  callbacks           = [var.callback_url]
  allowed_logout_urls = [var.logout_url]
  web_origins         = [var.web_origin]
  allowed_origins     = [var.web_origin]

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
  name            = "${var.install_name}-native"
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

# Auth0 Action to add email claim to access token
resource "auth0_action" "add_email_claim" {
  name    = "add-email-claim"
  code    = <<-EOT
    exports.onExecutePostLogin = async (event, api) => {
      const email = event.user.email;
      
      // Set email claim in the access token
      api.accessToken.setCustomClaim(`email`, email);
    };
  EOT
  deploy  = true
  runtime = "node22"
  supported_triggers {
    id      = "post-login"
    version = "v3"
  }
}

# Auth0 API resource for authentication (as specified in README)
resource "auth0_resource_server" "api" {
  name       = "API Gateway ${var.install_name}"
  identifier = "https://api.${var.public_domain}"

  # Enable RBAC for the API
  enforce_policies = true
  token_lifetime   = 2592000
  token_dialect    = "access_token_authz"

  # Allow skipping user consent during authorization
  skip_consent_for_verifiable_first_party_clients = true

  # Allow offline access (refresh tokens)
  allow_offline_access = true
}
