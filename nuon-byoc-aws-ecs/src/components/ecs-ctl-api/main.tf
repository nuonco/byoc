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
variable "cluster_arn" { type = string }
variable "cloud_map_namespace_id" { type = string }
variable "log_group_name" { type = string }
variable "execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "aurora_credentials_secret_arn" { type = string }
variable "aurora_cluster_endpoint" { type = string }
variable "clickhouse_password_secret_arn" { type = string }
variable "alb_https_listener_arn" { type = string }
variable "alb_security_group_id" { type = string }
variable "ctl_api_image" { type = string }
variable "public_root_domain" { type = string }
variable "admin_host" { type = string }
variable "enable_spot_workers" {
  type    = bool
  default = true
}

locals {
  prefix = "n-${var.install_id}"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "ecs-ctl-api"
  }
  public_hosts = [
    "api.${var.public_root_domain}",
    "auth.${var.public_root_domain}",
    "runner.${var.public_root_domain}",
    "slack.${var.public_root_domain}",
  ]
  worker_cap = var.enable_spot_workers ? "FARGATE_SPOT" : "FARGATE"
  shared_env = [
    { name = "AWS_REGION", value = var.region },
    { name = "DB_HOST", value = var.aurora_cluster_endpoint },
    { name = "DB_PORT", value = "5432" },
    { name = "DB_NAME", value = "ctl_api" },
    { name = "TEMPORAL_HOST", value = "temporal.nuon-byoc.local:7233" },
    { name = "CLICKHOUSE_DB_HOST", value = "clickhouse.nuon-byoc.local" },
    { name = "CLICKHOUSE_DB_PORT", value = "9000" },
    { name = "CLICKHOUSE_DB_USER", value = "ctl_api" },
    { name = "CLICKHOUSE_DB_NAME", value = "ctl_api" },
  ]
  shared_secrets = [
    { name = "DB_USER", valueFrom = "${var.aurora_credentials_secret_arn}:username::" },
    { name = "DB_PASSWORD", valueFrom = "${var.aurora_credentials_secret_arn}:password::" },
    { name = "CLICKHOUSE_DB_PASSWORD", valueFrom = var.clickhouse_password_secret_arn },
  ]
}

resource "aws_security_group" "ctl_api" {
  name        = "${local.prefix}-ctl-api"
  description = "ctl-api ingress from ALB + intra-VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
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

# ---------- ctl-api-public ----------
resource "aws_lb_target_group" "public" {
  name        = "${local.prefix}-public"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

resource "aws_lb_listener_rule" "public" {
  listener_arn = var.alb_https_listener_arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public.arn
  }

  condition {
    host_header { values = local.public_hosts }
  }
}

resource "aws_ecs_task_definition" "public" {
  family                   = "${local.prefix}-ctl-api-public"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name             = "ctl-api"
    image            = var.ctl_api_image
    essential        = true
    command          = ["ctl-api", "serve"]
    portMappings     = [{ containerPort = 8080, protocol = "tcp" }]
    environment      = concat(local.shared_env, [{ name = "CTL_API_ROLE", value = "public" }])
    secrets          = local.shared_secrets
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ctl-api-public"
      }
    }
  }])
}

resource "aws_ecs_service" "public" {
  name            = "${local.prefix}-ctl-api-public"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.public.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.ctl_api.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.public.arn
    container_name   = "ctl-api"
    container_port   = 8080
  }

  enable_execute_command = true
  lifecycle { ignore_changes = [task_definition] }
}

# ---------- ctl-api-admin ----------
resource "aws_lb_target_group" "admin" {
  name        = "${local.prefix}-admin"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

resource "aws_lb_listener_rule" "admin" {
  listener_arn = var.alb_https_listener_arn
  priority     = 210

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin.arn
  }

  condition {
    host_header { values = [var.admin_host] }
  }
}

resource "aws_ecs_task_definition" "admin" {
  family                   = "${local.prefix}-ctl-api-admin"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name             = "ctl-api"
    image            = var.ctl_api_image
    essential        = true
    command          = ["ctl-api", "serve"]
    portMappings     = [{ containerPort = 8080, protocol = "tcp" }]
    environment      = concat(local.shared_env, [{ name = "CTL_API_ROLE", value = "admin" }])
    secrets          = local.shared_secrets
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ctl-api-admin"
      }
    }
  }])
}

resource "aws_ecs_service" "admin" {
  name            = "${local.prefix}-ctl-api-admin"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.admin.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.ctl_api.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.admin.arn
    container_name   = "ctl-api"
    container_port   = 8080
  }

  enable_execute_command = true
  lifecycle { ignore_changes = [task_definition] }
}

# ---------- ctl-api-workers ----------
resource "aws_ecs_task_definition" "workers" {
  family                   = "${local.prefix}-ctl-api-workers"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name             = "ctl-api"
    image            = var.ctl_api_image
    essential        = true
    command          = ["ctl-api", "worker"]
    environment      = concat(local.shared_env, [{ name = "CTL_API_ROLE", value = "worker" }])
    secrets          = local.shared_secrets
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ctl-api-workers"
      }
    }
  }])
}

resource "aws_ecs_service" "workers" {
  name            = "${local.prefix}-ctl-api-workers"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.workers.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = local.worker_cap
    weight            = 1
  }

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.ctl_api.id]
    assign_public_ip = false
  }

  enable_execute_command = true
  lifecycle { ignore_changes = [task_definition] }
}

output "security_group_id" { value = aws_security_group.ctl_api.id }
output "public_target_group_arn" { value = aws_lb_target_group.public.arn }
output "admin_target_group_arn" { value = aws_lb_target_group.admin.arn }
