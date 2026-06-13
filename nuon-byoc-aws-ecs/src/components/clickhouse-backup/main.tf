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
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "cluster_arn" { type = string }
variable "cluster_name" { type = string }
variable "log_group_name" { type = string }
variable "execution_role_arn" { type = string }
variable "clickhouse_task_role_arn" { type = string }
variable "clickhouse_security_group_id" { type = string }
variable "clickhouse_backup_bucket" { type = string }
variable "clickhouse_password_secret_arn" { type = string }
variable "schedule_expression" {
  type    = string
  default = "cron(0 7 * * ? *)"
}
variable "backup_image" {
  type    = string
  default = "altinity/clickhouse-backup:2.5"
}

locals {
  name = "n-${var.install_id}-clickhouse-backup"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "clickhouse-backup"
  }
}

resource "aws_ecs_task_definition" "backup" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.clickhouse_task_role_arn

  container_definitions = jsonencode([{
    name      = "backup"
    image     = var.backup_image
    essential = true
    command   = ["create_remote", "scheduled-$(date -u +%Y%m%dT%H%M%S)"]
    environment = [
      { name = "CLICKHOUSE_HOST", value = "clickhouse.nuon-byoc.local" },
      { name = "CLICKHOUSE_PORT", value = "9000" },
      { name = "CLICKHOUSE_USERNAME", value = "ctl_api" },
      { name = "REMOTE_STORAGE", value = "s3" },
      { name = "S3_BUCKET", value = var.clickhouse_backup_bucket },
      { name = "S3_REGION", value = var.region },
      { name = "S3_PATH", value = "backups/" },
    ]
    secrets = [{
      name      = "CLICKHOUSE_PASSWORD"
      valueFrom = var.clickhouse_password_secret_arn
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "clickhouse-backup"
      }
    }
  }])
}

# EventBridge needs a role to call ECS RunTask + PassRole on execution+task roles.
resource "aws_iam_role" "events" {
  name = "${local.name}-events"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "events" {
  role = aws_iam_role.events.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:RunTask"]
        Resource = "${aws_ecs_task_definition.backup.arn_without_revision}:*"
        Condition = {
          ArnLike = { "ecs:cluster" = var.cluster_arn }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = [var.execution_role_arn, var.clickhouse_task_role_arn]
      },
    ]
  })
}

resource "aws_cloudwatch_event_rule" "nightly" {
  name                = local.name
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "run_task" {
  rule     = aws_cloudwatch_event_rule.nightly.name
  arn      = var.cluster_arn
  role_arn = aws_iam_role.events.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.backup.arn_without_revision
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = var.private_subnet_ids
      security_groups  = [var.clickhouse_security_group_id]
      assign_public_ip = false
    }
  }
}

output "task_family" { value = aws_ecs_task_definition.backup.family }
output "schedule_rule_name" { value = aws_cloudwatch_event_rule.nightly.name }
