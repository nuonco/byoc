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
variable "vpc_cidr" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "cluster_arn" { type = string }
variable "cluster_name" { type = string }
variable "cloud_map_namespace_id" { type = string }
variable "log_group_name" { type = string }
variable "execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "clickhouse_password_secret_arn" { type = string }
variable "task_cpu" {
  type    = number
  default = 512
}
variable "task_memory" {
  type    = number
  default = 4096
}
variable "volume_size_gb" {
  type    = number
  default = 50
}
variable "clickhouse_image" {
  type    = string
  default = "clickhouse/clickhouse-server:24.8"
}

locals {
  name   = "n-${var.install_id}-clickhouse"
  volume = "clickhouse-data"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "ecs-clickhouse"
  }
}

resource "aws_iam_role" "ebs" {
  name = "${local.name}-ebs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs" {
  role       = aws_iam_role.ebs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForVolumes"
}

resource "aws_security_group" "clickhouse" {
  name        = local.name
  description = "ClickHouse native + HTTP from VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    from_port   = 8123
    to_port     = 8123
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_service_discovery_service" "clickhouse" {
  name = "clickhouse"

  dns_config {
    namespace_id = var.cloud_map_namespace_id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config { failure_threshold = 1 }
}

resource "aws_ecs_task_definition" "clickhouse" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  volume {
    name                = local.volume
    configure_at_launch = true
  }

  container_definitions = jsonencode([{
    name      = "clickhouse"
    image     = var.clickhouse_image
    essential = true
    portMappings = [
      { containerPort = 9000, protocol = "tcp" },
      { containerPort = 8123, protocol = "tcp" },
    ]
    mountPoints = [{
      sourceVolume  = local.volume
      containerPath = "/var/lib/clickhouse"
    }]
    secrets = [{
      name      = "CLICKHOUSE_PASSWORD"
      valueFrom = var.clickhouse_password_secret_arn
    }]
    environment = [
      { name = "CLICKHOUSE_USER", value = "ctl_api" },
      { name = "CLICKHOUSE_DB", value = "ctl_api" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "clickhouse"
      }
    }
  }])
}

resource "aws_ecs_service" "clickhouse" {
  name                   = local.name
  cluster                = var.cluster_arn
  task_definition        = aws_ecs_task_definition.clickhouse.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.clickhouse.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.clickhouse.arn
  }

  volume_configuration {
    name = local.volume
    managed_ebs_volume {
      role_arn          = aws_iam_role.ebs.arn
      size_in_gb        = var.volume_size_gb
      volume_type       = "gp3"
      file_system_type  = "ext4"
      encrypted         = true
      throughput        = 125
      iops              = 3000
    }
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  lifecycle {
    ignore_changes = [task_definition]
  }
}

output "service_dns_name" {
  value = "clickhouse.${trimsuffix(replace(var.cloud_map_namespace_id, "ns-", ""), "")}"
}

output "service_name" { value = aws_ecs_service.clickhouse.name }
output "security_group_id" { value = aws_security_group.clickhouse.id }
