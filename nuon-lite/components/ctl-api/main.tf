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
variable "ctl_api_image" { type = string }
variable "public_root_domain" { type = string }
variable "admin_host" { type = string }

variable "clickhouse_host" { type = string }
variable "clickhouse_port" { type = string }
variable "clickhouse_database" { type = string }
variable "clickhouse_username" { type = string }
variable "clickhouse_tls" { type = string }
variable "clickhouse_password_secret_arn" { type = string }

variable "nuon_env" { type = string }

variable "auth_provider_type" { type = string }
variable "auth_issuer_url" { type = string }
variable "auth_client_id" { type = string }
variable "auth_allow_all_users" { type = string }
variable "auth_allowed_domains" { type = string }
variable "auth_session_key_secret_arn" { type = string }
variable "auth_client_secret_secret_arn" { type = string }

variable "github_app_id" { type = string }
variable "github_app_client_id" { type = string }
variable "github_app_name" { type = string }
variable "github_app_key_secret_arn" { type = string }

variable "slack_client_id" { type = string }
variable "slack_oauth_redirect_url" { type = string }
variable "slack_client_secret_secret_arn" { type = string }
variable "slack_signing_secret_secret_arn" { type = string }
variable "slack_state_jwt_secret_secret_arn" { type = string }

variable "loops_api_key_secret_arn" {
  type        = string
  description = "ARN of the loops_api_key secret. Empty string disables outbound email."
  default     = ""
}

# Temporal Cloud config is discovered by tag (matches subnet discovery
# pattern elsewhere in this app). The temporal-cloud component tags each
# workload-key secret with domain, namespace-id, and endpoint, so this
# module does not need any temporal vars passed through tfvars.
data "aws_secretsmanager_secrets" "temporal_workload" {
  filter {
    name   = "tag-key"
    values = ["nuon.co/temporal-domain"]
  }
  filter {
    name   = "tag-key"
    values = ["install.nuon.co/id"]
  }
}

data "aws_secretsmanager_secret" "temporal_workload" {
  for_each = toset(data.aws_secretsmanager_secrets.temporal_workload.arns)
  arn      = each.value
}

locals {
  # Filter to only this install's secrets (the tag-key filter above is
  # not value-scoped).
  temporal_workers = {
    for s in data.aws_secretsmanager_secret.temporal_workload :
    s.tags["nuon.co/temporal-domain"] => {
      arn          = s.arn
      namespace_id = s.tags["nuon.co/temporal-namespace-id"]
      endpoint     = s.tags["nuon.co/temporal-endpoint"]
    }
    if lookup(s.tags, "install.nuon.co/id", "") == var.install_id
  }
  temporal_endpoint = length(local.temporal_workers) > 0 ? values(local.temporal_workers)[0].endpoint : ""
}

locals {
  prefix = "n-${var.install_id}"
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "ctl-api"
  }
  public_hosts = [
    "api.${var.public_root_domain}",
    "auth.${var.public_root_domain}",
    "runner.${var.public_root_domain}",
    "slack.${var.public_root_domain}",
  ]

  shared_env = [
    { name = "AWS_REGION", value = var.region },
    { name = "NUON_ENV", value = var.nuon_env },
    { name = "DB_HOST", value = var.aurora_cluster_endpoint },
    { name = "DB_PORT", value = "5432" },
    { name = "DB_NAME", value = "ctl_api" },
    { name = "CLICKHOUSE_DB_HOST", value = var.clickhouse_host },
    { name = "CLICKHOUSE_DB_PORT", value = var.clickhouse_port },
    { name = "CLICKHOUSE_DB_USER", value = var.clickhouse_username },
    { name = "CLICKHOUSE_DB_NAME", value = var.clickhouse_database },
    { name = "CLICKHOUSE_DB_TLS", value = var.clickhouse_tls },
    { name = "TEMPORAL_HOST", value = local.temporal_endpoint },
    { name = "TEMPORAL_AUTH_METHOD", value = "api_key" },
    { name = "NUON_AUTH_PROVIDER_TYPE", value = var.auth_provider_type },
    { name = "NUON_AUTH_ISSUER_URL", value = var.auth_issuer_url },
    { name = "NUON_AUTH_CLIENT_ID", value = var.auth_client_id },
    { name = "NUON_AUTH_ALLOW_ALL_USERS", value = var.auth_allow_all_users },
    { name = "NUON_AUTH_ALLOWED_DOMAINS", value = var.auth_allowed_domains },
    { name = "GITHUB_APP_ID", value = var.github_app_id },
    { name = "GITHUB_APP_CLIENT_ID", value = var.github_app_client_id },
    { name = "GITHUB_APP_NAME", value = var.github_app_name },
    { name = "SLACK_CLIENT_ID", value = var.slack_client_id },
    { name = "SLACK_OAUTH_REDIRECT_URL", value = var.slack_oauth_redirect_url },
  ]
  base_secrets = [
    { name = "DB_USER", valueFrom = "${var.aurora_credentials_secret_arn}:username::" },
    { name = "DB_PASSWORD", valueFrom = "${var.aurora_credentials_secret_arn}:password::" },
    { name = "CLICKHOUSE_DB_PASSWORD", valueFrom = var.clickhouse_password_secret_arn },
    { name = "NUON_AUTH_SESSION_KEY", valueFrom = var.auth_session_key_secret_arn },
    { name = "NUON_AUTH_CLIENT_SECRET", valueFrom = var.auth_client_secret_secret_arn },
    { name = "GITHUB_APP_PRIVATE_KEY", valueFrom = var.github_app_key_secret_arn },
    { name = "SLACK_CLIENT_SECRET", valueFrom = var.slack_client_secret_secret_arn },
    { name = "SLACK_SIGNING_SECRET", valueFrom = var.slack_signing_secret_secret_arn },
    { name = "SLACK_STATE_JWT_SECRET", valueFrom = var.slack_state_jwt_secret_secret_arn },
  ]
  loops_secret   = var.loops_api_key_secret_arn != "" ? [{ name = "LOOPS_API_KEY", valueFrom = var.loops_api_key_secret_arn }] : []
  shared_secrets = concat(local.base_secrets, local.loops_secret)
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

# ---------- ctl-api-workers (one per Temporal namespace) ----------
# Each worker process owns a single namespace via TEMPORAL_NAMESPACE +
# its own workload API key, matching byoc-nuon's per-domain worker layout.
# To consolidate cost later, multiple domains can be folded into one task
# def (multi-container) or onto a single namespace + task queue separation
# (requires ctl-api code change). See nuon-lite/docs/design.md.
resource "aws_ecs_task_definition" "worker" {
  for_each = local.temporal_workers

  family                   = "${local.prefix}-ctl-api-worker-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "ctl-api"
    image     = var.ctl_api_image
    essential = true
    command   = ["ctl-api", "worker", "--namespace", each.key]
    environment = concat(local.shared_env, [
      { name = "CTL_API_ROLE", value = "worker" },
      { name = "TEMPORAL_NAMESPACE", value = each.value.namespace_id },
      { name = "TEMPORAL_DOMAIN", value = each.key },
    ])
    secrets = concat(local.shared_secrets, [
      { name = "TEMPORAL_API_KEY", valueFrom = each.value.arn },
    ])
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "ctl-api-worker-${each.key}"
      }
    }
  }])
}

resource "aws_ecs_service" "worker" {
  for_each = local.temporal_workers

  name            = "${local.prefix}-ctl-api-worker-${each.key}"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.worker[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

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
