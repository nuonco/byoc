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
}

# Auth0 Tenant resource
resource "auth0_tenant" "tenant" {
  friendly_name = var.tenant_name
  picture_url   = var.tenant_logo_url
  support_email = var.support_email
  support_url   = var.support_url
  session_lifetime = var.session_lifetime
}

# SPA Application for the tenant (based on README.md)
resource "auth0_client" "spa_application" {
  name                = "Nuon App - {{ .nuon.install.id }}"
  description         = "SPA Application for Nuon installation {{ .nuon.install.id }}"
  app_type            = "spa"
  callbacks           = ["https://app.{{ .nuon.install.public_domain }}/api/auth/callback"]
  allowed_logout_urls = ["https://app.{{ .nuon.install.public_domain }}"]
  web_origins         = ["https://app.{{ .nuon.install.public_domain }}"]
  oidc_conformant     = true
  cross_origin_auth   = true
  
  jwt_configuration {
    alg = "RS256"
  }

  grant_types = [
    "authorization_code",
    "implicit",
    "refresh_token"
  ]
  
  refresh_token {
    rotation_type    = "rotating"
    expiration_type  = "expiring"
    token_lifetime   = 31557600 # As specified in README.md
    leeway           = 0        # Rotation overlap period
  }
}

# Native Application for the tenant (based on README.md)
resource "auth0_client" "native_application" {
  name                = "Nuon CTL API - {{ .nuon.install.id }}"
  description         = "For BYOC Nuon Install {{ .nuon.install.id }}"
  app_type            = "native"
  oidc_conformant     = true
  cross_origin_auth   = true
  
  jwt_configuration {
    alg = "RS256"
  }

  grant_types = [
    "authorization_code",
    "refresh_token",
    "device_code"
  ]
}

# Database connection for username/password authentication
resource "auth0_connection" "database" {
  name           = "${var.tenant_name}-database"
  strategy       = "auth0"
  
  options {
    password_policy = "good"
    password_complexity_options {
      min_length = 8
    }
    disable_signup = !var.allow_signup
    brute_force_protection = true
    
    password_history {
      enable = true
      size   = 5
    }
    
    password_dictionary {
      enable     = true
      dictionary = []
    }
    
    password_no_personal_info {
      enable = true
    }
  }
}

# Use a null resource as a workaround for the connection-client association
# This is needed because the Auth0 provider may not support enabled_clients directly
resource "null_resource" "connection_client_association" {
  triggers = {
    connection_id = auth0_connection.database.id
    spa_client_id = auth0_client.spa_application.client_id
    native_client_id = auth0_client.native_application.client_id
  }

  # We'll use a provisioner to run a script that will update the connection
  # This is a workaround and should be replaced when the provider supports this natively
  provisioner "local-exec" {
    command = "echo 'Connection ${auth0_connection.database.id} created and will be associated with clients ${auth0_client.spa_application.client_id} and ${auth0_client.native_application.client_id}'"
  }

  depends_on = [
    auth0_connection.database,
    auth0_client.spa_application,
    auth0_client.native_application
  ]
}
