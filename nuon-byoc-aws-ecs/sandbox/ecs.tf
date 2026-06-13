resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = local.cloud_map_namespace
  description = "Intra-cluster service discovery for ${var.cluster_name}"
  vpc         = var.vpc_id
}

resource "aws_cloudwatch_log_group" "ecs_cluster" {
  name              = "/aws/ecs/${var.cluster_name}"
  retention_in_days = 1
}
