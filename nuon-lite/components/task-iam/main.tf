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
variable "aurora_credentials_secret_arn" { type = string }
variable "clickhouse_password_secret_arn" { type = string }
variable "blob_bucket_arn" { type = string }
variable "install_templates_bucket_arn" { type = string }
variable "clickhouse_backup_bucket_arn" { type = string }

locals {
  prefix = "n-${var.install_id}"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "task-iam"
  }
  ecs_tasks_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Shared execution role — pulls images, writes logs, reads task-startup secrets.
resource "aws_iam_role" "execution" {
  name               = "${local.prefix}-task-execution"
  assume_role_policy = local.ecs_tasks_trust
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "execution_secrets" {
  name = "secrets-read"
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # All install_stack-managed secrets live under the install id prefix.
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.install_id}/*",
        ]
      },
      {
        # Temporal workload API key secrets are created at deploy time by
        # the temporal-namespaces component, one per namespace.
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:n-${var.install_id}-temporal-*",
        ]
      },
      {
        # ctl-api-db component creates its own credentials secret.
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          var.aurora_credentials_secret_arn,
        ]
      },
    ]
  })
}

# ctl-api task role — needs S3 (blob + install templates) + Aurora creds.
resource "aws_iam_role" "ctl_api" {
  name               = "${local.prefix}-ctl-api"
  assume_role_policy = local.ecs_tasks_trust
}

resource "aws_iam_role_policy" "ctl_api" {
  name = "ctl-api"
  role = aws_iam_role.ctl_api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          var.blob_bucket_arn, "${var.blob_bucket_arn}/*",
          var.install_templates_bucket_arn, "${var.install_templates_bucket_arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          var.aurora_credentials_secret_arn,
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.install_id}/*",
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:n-${var.install_id}-temporal-*",
        ]
      },
    ]
  })
}

# Temporal task role — Aurora creds only.
resource "aws_iam_role" "temporal" {
  name               = "${local.prefix}-temporal"
  assume_role_policy = local.ecs_tasks_trust
}

resource "aws_iam_role_policy" "temporal" {
  name = "temporal"
  role = aws_iam_role.temporal.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.aurora_credentials_secret_arn]
    }]
  })
}

# Dashboard task role — no AWS API access beyond execution role basics.
resource "aws_iam_role" "dashboard" {
  name               = "${local.prefix}-dashboard"
  assume_role_policy = local.ecs_tasks_trust
}

# ClickHouse task role — backup bucket + password.
resource "aws_iam_role" "clickhouse" {
  name               = "${local.prefix}-clickhouse"
  assume_role_policy = local.ecs_tasks_trust
}

resource "aws_iam_role_policy" "clickhouse" {
  name = "clickhouse"
  role = aws_iam_role.clickhouse.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          var.clickhouse_backup_bucket_arn,
          "${var.clickhouse_backup_bucket_arn}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.clickhouse_password_secret_arn]
      },
    ]
  })
}

output "execution_role_arn" { value = aws_iam_role.execution.arn }
output "ctl_api_task_role_arn" { value = aws_iam_role.ctl_api.arn }
output "temporal_task_role_arn" { value = aws_iam_role.temporal.arn }
output "dashboard_task_role_arn" { value = aws_iam_role.dashboard.arn }
output "clickhouse_task_role_arn" { value = aws_iam_role.clickhouse.arn }
