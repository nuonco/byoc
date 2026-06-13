terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}

variable "region" { type = string }
variable "install_id" { type = string }
variable "org_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "cluster_arn" { type = string }
variable "log_group_name" { type = string }
variable "execution_role_arn" { type = string }
variable "ctl_api_task_role_arn" { type = string }
variable "temporal_task_role_arn" { type = string }
variable "aurora_credentials_secret_arn" { type = string }
variable "aurora_cluster_endpoint" { type = string }
variable "ctl_api_image" {
  type        = string
  description = "ctl-api image used to run Aurora migrations (provides `ctl-api migrate`)."
}
variable "temporal_admin_image" {
  type    = string
  default = "temporalio/admin-tools:1.24"
}

locals {
  name = "n-${var.install_id}"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "ecs-aurora-init"
  }
}

# Task def: creates `temporal` database (if missing) + runs ctl-api migrations
# against `ctl_api` + runs `temporal-sql-tool setup-schema && update-schema`.
# Triggered by `aws ecs run-task` from the deploy runbook, not by a long-running service.
resource "aws_ecs_task_definition" "aurora_init" {
  family                   = "${local.name}-aurora-init"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.ctl_api_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "ctl-api-migrate"
      image     = var.ctl_api_image
      essential = true
      command   = ["ctl-api", "migrate", "up"]
      secrets = [{
        name      = "DB_URL"
        valueFrom = "${var.aurora_credentials_secret_arn}:url::"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "aurora-init"
        }
      }
    },
    {
      name      = "temporal-schema"
      image     = var.temporal_admin_image
      essential = true
      dependsOn = [{ containerName = "ctl-api-migrate", condition = "SUCCESS" }]
      command   = ["sh", "-c", "temporal-sql-tool setup-schema -v 0.0 && temporal-sql-tool update-schema -d schema/postgresql/v12/temporal/versioned"]
      environment = [
        { name = "SQL_PLUGIN", value = "postgres12" },
        { name = "SQL_HOST", value = var.aurora_cluster_endpoint },
        { name = "SQL_PORT", value = "5432" },
        { name = "SQL_DATABASE", value = "temporal" },
      ]
      secrets = [
        { name = "SQL_USER", valueFrom = "${var.aurora_credentials_secret_arn}:username::" },
        { name = "SQL_PASSWORD", valueFrom = "${var.aurora_credentials_secret_arn}:password::" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "aurora-init"
        }
      }
    },
  ])
}

output "task_definition_arn" { value = aws_ecs_task_definition.aurora_init.arn }
output "task_family" { value = aws_ecs_task_definition.aurora_init.family }
