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
variable "task_role_arn" { type = string }
variable "alb_https_listener_arn" { type = string }
variable "alb_security_group_id" { type = string }
variable "dashboard_image" { type = string }
variable "dashboard_host" { type = string }
variable "api_host" { type = string }
variable "admin_dashboard_enabled" {
  type    = bool
  default = false
}
variable "admin_dashboard_host" {
  type    = string
  default = ""
}

locals {
  prefix = "n-${var.install_id}-dashboard"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "dashboard"
  }
}

resource "aws_security_group" "dashboard" {
  name        = local.prefix
  description = "Dashboard UI ingress from ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
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

resource "aws_lb_target_group" "dashboard" {
  name        = local.prefix
  port        = 3000
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

resource "aws_lb_listener_rule" "dashboard" {
  listener_arn = var.alb_https_listener_arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dashboard.arn
  }

  condition {
    host_header { values = [var.dashboard_host] }
  }
}

resource "aws_ecs_task_definition" "dashboard" {
  family                   = local.prefix
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name         = "dashboard"
    image        = var.dashboard_image
    essential    = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    environment = [
      { name = "NUON_API_URL", value = "https://${var.api_host}" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "dashboard"
      }
    }
  }])
}

resource "aws_ecs_service" "dashboard" {
  name            = local.prefix
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.dashboard.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.dashboard.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.dashboard.arn
    container_name   = "dashboard"
    container_port   = 3000
  }

  enable_execute_command = true
  lifecycle { ignore_changes = [task_definition] }
}

output "target_group_arn" { value = aws_lb_target_group.dashboard.arn }

# ---------- admin dashboard (optional) ----------
resource "aws_lb_target_group" "admin" {
  count       = var.admin_dashboard_enabled ? 1 : 0
  name        = "${local.prefix}-admin"
  port        = 3000
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

resource "aws_lb_listener_rule" "admin" {
  count        = var.admin_dashboard_enabled ? 1 : 0
  listener_arn = var.alb_https_listener_arn
  priority     = 310

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.admin[0].arn
  }

  condition {
    host_header { values = [var.admin_dashboard_host] }
  }
}

resource "aws_ecs_task_definition" "admin" {
  count                    = var.admin_dashboard_enabled ? 1 : 0
  family                   = "${local.prefix}-admin"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name         = "dashboard"
    image        = var.dashboard_image
    essential    = true
    portMappings = [{ containerPort = 3000, protocol = "tcp" }]
    environment = [
      { name = "NUON_API_URL", value = "https://${var.api_host}" },
      { name = "NUON_DASHBOARD_MODE", value = "admin" },
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "dashboard-admin"
      }
    }
  }])
}

resource "aws_ecs_service" "admin" {
  count           = var.admin_dashboard_enabled ? 1 : 0
  name            = "${local.prefix}-admin"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.admin[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.dashboard.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.admin[0].arn
    container_name   = "dashboard"
    container_port   = 3000
  }

  enable_execute_command = true
  lifecycle { ignore_changes = [task_definition] }
}
