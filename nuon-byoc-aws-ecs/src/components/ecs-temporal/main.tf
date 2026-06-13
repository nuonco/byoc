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
variable "alb_https_listener_arn" { type = string }
variable "alb_security_group_id" { type = string }
variable "temporal_ui_host" {
  type        = string
  description = "Public host for the Temporal UI (e.g. temporal.<nuon_dns_domain>)."
}
variable "server_image" { type = string }
variable "ui_image" { type = string }
variable "enable_spot" {
  type    = bool
  default = true
}

locals {
  prefix = "n-${var.install_id}-temporal"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "ecs-temporal"
  }
  capacity_provider = var.enable_spot ? "FARGATE_SPOT" : "FARGATE"
}

resource "aws_security_group" "temporal" {
  name        = local.prefix
  description = "Temporal server (7233) + UI (8080) ingress from VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 7233
    to_port     = 7233
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- Temporal server ----------
resource "aws_service_discovery_service" "server" {
  name = "temporal"
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

resource "aws_ecs_task_definition" "server" {
  family                   = "${local.prefix}-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "temporal"
    image     = var.server_image
    essential = true
    portMappings = [{ containerPort = 7233, protocol = "tcp" }]
    environment = [
      { name = "DB", value = "postgres12" },
      { name = "DB_PORT", value = "5432" },
      { name = "POSTGRES_SEEDS", value = var.aurora_cluster_endpoint },
      { name = "DBNAME", value = "temporal" },
      { name = "VISIBILITY_DBNAME", value = "temporal" },
      { name = "SKIP_SCHEMA_SETUP", value = "true" },
    ]
    secrets = [
      { name = "POSTGRES_USER", valueFrom = "${var.aurora_credentials_secret_arn}:username::" },
      { name = "POSTGRES_PWD", valueFrom = "${var.aurora_credentials_secret_arn}:password::" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "temporal-server"
      }
    }
  }])
}

resource "aws_ecs_service" "server" {
  name            = "${local.prefix}-server"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = local.capacity_provider
    weight            = 1
  }

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.temporal.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.server.arn
  }

  enable_execute_command = true
  lifecycle { ignore_changes = [task_definition] }
}

# ---------- Temporal UI ----------
resource "aws_lb_target_group" "ui" {
  name        = "${local.prefix}-ui"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
  }
}

resource "aws_lb_listener_rule" "ui" {
  listener_arn = var.alb_https_listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }

  condition {
    host_header { values = [var.temporal_ui_host] }
  }
}

resource "aws_ecs_task_definition" "ui" {
  family                   = "${local.prefix}-ui"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "temporal-ui"
    image     = var.ui_image
    essential = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "TEMPORAL_ADDRESS", value = "temporal.nuon-byoc.local:7233" },
      { name = "TEMPORAL_UI_PUBLIC_PATH", value = "/" },
      { name = "TEMPORAL_CORS_ORIGINS", value = "https://${var.temporal_ui_host}" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "temporal-ui"
      }
    }
  }])
}

resource "aws_ecs_service" "ui" {
  name            = "${local.prefix}-ui"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = local.capacity_provider
    weight            = 1
  }

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.temporal.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ui.arn
    container_name   = "temporal-ui"
    container_port   = 8080
  }

  enable_execute_command = true
  lifecycle { ignore_changes = [task_definition] }
}

output "server_security_group_id" { value = aws_security_group.temporal.id }
output "server_dns" { value = "temporal.nuon-byoc.local" }
