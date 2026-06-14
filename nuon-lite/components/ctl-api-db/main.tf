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
variable "vpc_cidr" { type = string }
variable "master_username_secret_arn" { type = string }
variable "master_password_secret_arn" { type = string }
variable "min_capacity" {
  type    = number
  default = 0.5
}
variable "max_capacity" {
  type    = number
  default = 1
}
variable "backup_retention_days" {
  type    = number
  default = 7
}

locals {
  cluster_id = "n-${var.install_id}"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "ctl-api-db"
  }
}

data "aws_secretsmanager_secret_version" "username" {
  secret_id = data.aws_secretsmanager_secret_version.username.secret_string_secret_arn
}

data "aws_secretsmanager_secret_version" "password" {
  secret_id = data.aws_secretsmanager_secret_version.password.secret_string_secret_arn
}

resource "aws_db_subnet_group" "main" {
  name       = local.cluster_id
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_security_group" "aurora" {
  name        = "${local.cluster_id}-aurora"
  description = "Allow Postgres from the VPC to Aurora"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier      = local.cluster_id
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "16.4"
  database_name           = "ctl_api"
  master_username         = data.aws_secretsmanager_secret_version.username.secret_string
  master_password         = data.aws_secretsmanager_secret_version.password.secret_string
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.aurora.id]
  backup_retention_period = var.backup_retention_days
  skip_final_snapshot     = true
  storage_encrypted       = true

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }
}

resource "aws_rds_cluster_instance" "main" {
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
  identifier         = "${local.cluster_id}-1"
}

# The temporal database is created by the Phase 3 init task; we only seed
# ctl_api at cluster creation time because Aurora requires exactly one
# initial database.

resource "aws_secretsmanager_secret" "creds" {
  name = "${local.cluster_id}-aurora-creds"
}

resource "aws_secretsmanager_secret_version" "creds" {
  secret_id = aws_secretsmanager_secret.creds.id
  secret_string = jsonencode({
    username = data.aws_secretsmanager_secret_version.username.secret_string
    password = data.aws_secretsmanager_secret_version.password.secret_string
    host     = aws_rds_cluster.main.endpoint
    port     = aws_rds_cluster.main.port
  })
}

output "cluster_endpoint" { value = aws_rds_cluster.main.endpoint }
output "cluster_port" { value = aws_rds_cluster.main.port }
output "cluster_reader_endpoint" { value = aws_rds_cluster.main.reader_endpoint }
output "security_group_id" { value = aws_security_group.aurora.id }
output "credentials_secret_arn" { value = aws_secretsmanager_secret.creds.arn }
