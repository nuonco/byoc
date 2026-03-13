output "management_account_id" {
  value = var.management_account_id
}

output "org_access_role" {
  value = {
    iam_role_arn = ""
  }
}

output "ecr_access_role" {
  value = {
    iam_role_arn = ""
  }
}

output "dns_zone" {
  value = {
    nameservers = var.dns_nameservers
    domain      = var.dns_domain
    zone_id     = var.dns_zone_id
    arn         = ""
  }
}

output "cluster" {
  value = {
    arn                        = ""
    certificate_authority_data = var.cluster.certificate_authority_data
    endpoint                   = var.cluster.endpoint
    name                       = var.cluster.name
    platform_version           = ""
    oidc_provider              = var.cluster.oidc_provider
    oidc_provider_arn          = ""
  }
}

output "registry" {
  value = {
    id           = var.acr.login_server
    arn          = ""
    resource_id  = var.acr.id
    login_server = var.acr.login_server
  }
}

output "app_ecr_registry_id" {
  value = var.acr.login_server
}

output "org_management_role_arn" {
  value = ""
}

output "dns_management_role_arn" {
  value = ""
}

output "ecr_management_role_arn" {
  value = ""
}

output "azure_tenant_id" {
  value = var.azure_tenant_id
}

output "azure_subscription_id" {
  value = var.azure_subscription_id
}

output "azure_resource_group" {
  value = var.azure_resource_group
}

output "azure_oidc_issuer_url" {
  value = var.azure_oidc_issuer_url
}

output "acr_registry_url" {
  value = var.acr.login_server
}
