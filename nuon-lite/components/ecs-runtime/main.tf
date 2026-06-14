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
variable "nuon_id" { type = string }
variable "vpc_id" { type = string }

data "aws_vpc" "this" { id = var.vpc_id }

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    visibility               = "private"
    "network.nuon.co/domain" = "internal"
    "install.nuon.co/id"     = var.nuon_id
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    visibility               = "public"
    "install.nuon.co/id"     = var.nuon_id
  }
}

locals {
  prefix = var.nuon_id
  tags = {
    "install.nuon.co/id"     = var.nuon_id
    "component.nuon.co/name" = "ecs-runtime"
  }
  interface_services = ["ecr.api", "ecr.dkr", "secretsmanager", "logs", "sts"]
}

resource "aws_ecs_cluster" "main" {
  name = local.prefix

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "nuon-lite.local"
  vpc  = var.vpc_id
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${local.prefix}"
  retention_in_days = 1
}

# VPC endpoints — keep ECS tasks in private subnets from needing NAT egress for AWS APIs.
resource "aws_security_group" "endpoints" {
  name        = "${local.prefix}-vpc-endpoints"
  description = "HTTPS from VPC to interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(local.interface_services)
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = data.aws_subnets.private.ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

data "aws_route_tables" "private" {
  vpc_id = var.vpc_id
  filter {
    name   = "association.subnet-id"
    values = data.aws_subnets.private.ids
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids
}

output "cluster_name" { value = aws_ecs_cluster.main.name }
output "cluster_arn" { value = aws_ecs_cluster.main.arn }
output "cloud_map_namespace_id" { value = aws_service_discovery_private_dns_namespace.main.id }
output "cloud_map_namespace_name" { value = aws_service_discovery_private_dns_namespace.main.name }
output "log_group_name" { value = aws_cloudwatch_log_group.ecs.name }
output "endpoint_security_group_id" { value = aws_security_group.endpoints.id }
output "vpc_cidr" { value = data.aws_vpc.this.cidr_block }
output "private_subnet_ids" { value = data.aws_subnets.private.ids }
output "public_subnet_ids" { value = data.aws_subnets.public.ids }
