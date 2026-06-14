terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# Billing metrics only publish in us-east-1.
provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags { tags = local.tags }
}

variable "region" { type = string }
variable "install_id" { type = string }
variable "org_id" { type = string }
variable "billing_threshold_usd" {
  type    = number
  default = 290
}

locals {
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "billing-alarm"
  }
}

# Topic and alarm both live in us-east-1 — that's where AWS publishes
# EstimatedCharges. The runner log groups are already created elsewhere with
# 1-day retention.
resource "aws_sns_topic" "billing" {
  provider = aws.us_east_1
  name     = "n-${var.install_id}-billing-alarm"
}

resource "aws_cloudwatch_metric_alarm" "billing" {
  provider            = aws.us_east_1
  alarm_name          = "n-${var.install_id}-estimated-charges"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours — Billing only publishes every ~6h
  statistic           = "Maximum"
  threshold           = var.billing_threshold_usd
  alarm_description   = "Account-wide AWS bill estimate exceeded $${var.billing_threshold_usd}/mo for ${var.install_id}"
  alarm_actions       = [aws_sns_topic.billing.arn]
  dimensions          = { Currency = "USD" }
}

output "billing_topic_arn" { value = aws_sns_topic.billing.arn }
