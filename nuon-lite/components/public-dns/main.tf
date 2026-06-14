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
variable "zone_id" { type = string }
variable "zone_name" { type = string }
variable "alb_dns_name" { type = string }
variable "alb_zone_id" { type = string }
variable "subdomains" {
  type    = list(string)
  default = ["api", "auth", "runner", "slack", "app", "admin", "temporal"]
}

locals {
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "public-dns"
  }
}

resource "aws_route53_record" "alias" {
  for_each = toset(var.subdomains)
  zone_id  = var.zone_id
  name     = "${each.value}.${var.zone_name}"
  type     = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = false
  }
}

output "records" {
  value = [for r in aws_route53_record.alias : r.fqdn]
}
