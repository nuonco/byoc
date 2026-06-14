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

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    visibility               = "private"
    "network.nuon.co/domain" = "internal"
    "install.nuon.co/id"     = var.install_id
  }
}

variable "region" { type = string }
variable "install_id" { type = string }
variable "org_id" { type = string }
variable "vpc_id" { type = string }
variable "cluster_arn" { type = string }
variable "log_group_name" { type = string }
variable "execution_role_arn" { type = string }
variable "ctl_api_task_role_arn" { type = string }
variable "aurora_credentials_secret_arn" { type = string }
variable "ctl_api_image" {
  type        = string
  description = "ctl-api image used to run Aurora migrations (provides `ctl-api migrate`)."
}

locals {
  name = "n-${var.install_id}"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "ctl-api-migrations"
  }
}

# Runs `ctl-api migrate up` against the ctl_api Aurora database.
# Triggered by `aws ecs run-task` from the deploy runbook, not by a long-running service.
# ClickHouse schema is auto-migrated by ctl-api on its first serve/worker boot
# (see ch.NewCHMigrator in ctl-api's startup subcommand). Temporal Cloud
# manages its own storage — no temporal-sql-tool needed.
resource "aws_ecs_task_definition" "ctl_api_init" {
  family                   = "${local.name}-ctl-api-init"
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
          "awslogs-stream-prefix" = "ctl-api-init"
        }
      }
    },
  ])
}

output "task_definition_arn" { value = aws_ecs_task_definition.ctl_api_init.arn }
output "task_family" { value = aws_ecs_task_definition.ctl_api_init.family }
