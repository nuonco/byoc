data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_route_tables" "private" {
  vpc_id = var.vpc_id
  filter {
    name   = "association.subnet-id"
    values = var.private_subnet_ids
  }
}

locals {
  interface_services = [
    "ecr.api",
    "ecr.dkr",
    "secretsmanager",
    "logs",
    "sts",
  ]
}

resource "aws_security_group" "endpoints" {
  name        = "n-${var.install_id}-vpc-endpoints"
  description = "Allow HTTPS from the VPC to interface endpoints"
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
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.private.ids
}
