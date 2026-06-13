output "region" {
  value = var.region
}

output "account" {
  value = {
    id = data.aws_caller_identity.current.account_id
  }
}

output "vpc" {
  value = {
    id                 = var.vpc_id
    public_subnet_ids  = var.public_subnet_ids
    private_subnet_ids = var.private_subnet_ids
    runner_subnet_id   = var.runner_subnet_id
  }
}

output "cluster" {
  value = {
    name                     = aws_ecs_cluster.main.name
    arn                      = aws_ecs_cluster.main.arn
    cloud_map_namespace_id   = aws_service_discovery_private_dns_namespace.main.id
    cloud_map_namespace_name = aws_service_discovery_private_dns_namespace.main.name
    log_group_name           = aws_cloudwatch_log_group.ecs_cluster.name
  }
}

output "ecr" {
  value = {
    registry_id    = aws_ecr_repository.runner.registry_id
    repository_arn = aws_ecr_repository.runner.arn
    repository_url = aws_ecr_repository.runner.repository_url
  }
}

output "vpc_endpoints" {
  value = {
    security_group_id = aws_security_group.endpoints.id
  }
}

output "nuon_dns" {
  value = {
    public_domain = var.enable_nuon_dns ? {
      name    = aws_route53_zone.public[0].name
      zone_id = aws_route53_zone.public[0].zone_id
    } : null
  }
}
