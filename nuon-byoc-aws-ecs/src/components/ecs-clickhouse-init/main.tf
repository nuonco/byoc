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
variable "log_group_name" { type = string }
variable "execution_role_arn" { type = string }
variable "ctl_api_task_role_arn" { type = string }
variable "ctl_api_image" {
  type        = string
  description = "ctl-api image that runs the ClickHouse schema migrations."
}
variable "clickhouse_password_secret_arn" { type = string }
variable "clickhouse_host" {
  type    = string
  default = "clickhouse.nuon-byoc.local"
}

locals {
  name = "n-${var.install_id}-clickhouse-init"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "ecs-clickhouse-init"
  }
}

resource "aws_ecs_task_definition" "ch_init" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.ctl_api_task_role_arn

  container_definitions = jsonencode([{
    name      = "ch-migrate"
    image     = var.ctl_api_image
    essential = true
    command   = ["ctl-api", "migrate-clickhouse", "up"]
    environment = [
      { name = "CLICKHOUSE_DB_HOST", value = var.clickhouse_host },
      { name = "CLICKHOUSE_DB_PORT", value = "9000" },
      { name = "CLICKHOUSE_DB_USER", value = "ctl_api" },
      { name = "CLICKHOUSE_DB_NAME", value = "ctl_api" },
    ]
    secrets = [{
      name      = "CLICKHOUSE_DB_PASSWORD"
      valueFrom = var.clickhouse_password_secret_arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "clickhouse-init"
      }
    }
  }])
}

output "task_definition_arn" { value = aws_ecs_task_definition.ch_init.arn }
output "task_family" { value = aws_ecs_task_definition.ch_init.family }
