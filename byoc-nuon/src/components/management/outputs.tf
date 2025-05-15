output "management_account_id" {
  value = var.management_account_id
}
# full outputs
output "org_access_role" {
  value = module.org_access_role
}

output "ecr_access_role" {
  value = module.ecr_access_role
}

output "route53_zone" {
  value = {
    nameservers = aws_route53_zone.root.name_servers
    domain      = aws_route53_zone.root.name
    zone_id     = aws_route53_zone.root.id
    arn         = aws_route53_zone.root.arn
  }
}

# details from the sandbox
output "cluster" {
  value = {
    arn                        = var.cluster.arn
    certificate_authority_data = var.cluster.certificate_authority_data
    endpoint                   = var.cluster.endpoint
    name                       = var.cluster.name
    platform_version           = var.cluster.platform_version
    oidc_issuer_url            = var.cluster.oidc_issuer_url
    oidc_provider_arn          = var.cluster.oidc_provider_arn
  }
}

output "ecr" {
  value = {
    id  = var.ecr.id
    arn = var.ecr.arn
  }
}

# simple formats
output "app_ecr_registry_id" {
  value = var.ecr.id
}

output "org_management_role_arn" {
  value = module.org_access_role.iam_role_arn
}

output "dns_management_role_arn" {
  value = module.dns_access_role.iam_role_arn
}

output "ecr_management_role_arn" {
  value = module.ecr_access_role.iam_role_arn
}
