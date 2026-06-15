terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    temporalcloud = {
      source  = "temporalio/temporalcloud"
      version = "~> 1.3"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}

data "aws_secretsmanager_secret_version" "tc_key" {
  secret_id = var.tc_account_api_key_secret_arn
}

provider "temporalcloud" {
  api_key        = data.aws_secretsmanager_secret_version.tc_key.secret_string
  endpoint       = "saas-api.tmprl.cloud:443"
  allow_insecure = false
}

variable "region" { type = string }
variable "install_id" { type = string }
variable "org_id" { type = string }
variable "tc_region" {
  type        = string
  description = "Temporal Cloud region (e.g. aws-us-east-1)."
}
variable "tc_retention_days" {
  type    = number
  default = 7
}
variable "tc_namespace_prefix" {
  type        = string
  description = "Prefix applied to every namespace name."
}
variable "tc_account_api_key_secret_arn" {
  type        = string
  description = "ARN of the install_stack-managed secret holding the Temporal Cloud account API key."
}

locals {
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "temporal-namespaces"
  }

  # Mirrors byoc-nuon/shared/src/actions/temporal/ensure_namespaces.sh.
  # Domains with override retention live in `extended_retention_domains`.
  default_domains          = ["orgs", "actions", "apps", "components", "installs", "releases", "general", "runners"]
  extended_retention_domains = ["vcs", "emitters"]
  extended_retention_days  = 30

  all_domains = concat(local.default_domains, local.extended_retention_domains)

  namespaces = {
    for d in local.all_domains : d => {
      name      = "${var.tc_namespace_prefix}-${d}"
      retention = contains(local.extended_retention_domains, d) ? local.extended_retention_days : var.tc_retention_days
    }
  }
}

resource "temporalcloud_namespace" "ns" {
  for_each = local.namespaces

  name               = each.value.name
  regions            = [var.tc_region]
  api_key_auth       = true
  retention_days     = each.value.retention
}

resource "temporalcloud_service_account" "workload" {
  for_each = local.namespaces

  name        = "${each.value.name}-workload"
  description = "Workload service account for ${each.value.name}, consumed by ctl-api."
  namespace_scoped_access = {
    namespace_id = temporalcloud_namespace.ns[each.key].id
    permission   = "write"
  }
}

resource "temporalcloud_apikey" "workload" {
  for_each = local.namespaces

  display_name = "${each.value.name}-workload"
  description  = "Workload API key for ${each.value.name}, consumed by ctl-api."
  owner_type   = "service-account"
  owner_id     = temporalcloud_service_account.workload[each.key].id
  expiry_time  = timeadd(timestamp(), "8760h") # 1 year
  lifecycle {
    ignore_changes = [expiry_time]
  }
}

resource "aws_secretsmanager_secret" "workload_key" {
  for_each = local.namespaces
  name     = "n-${var.install_id}-temporal-${each.key}-apikey"
  tags = merge(local.tags, {
    "nuon.co/temporal-domain"       = each.key
    "nuon.co/temporal-namespace-id" = temporalcloud_namespace.ns[each.key].namespace_id
    "nuon.co/temporal-endpoint"     = "${var.tc_region}.api.temporal.io:7233"
  })
}

resource "aws_secretsmanager_secret_version" "workload_key" {
  for_each      = local.namespaces
  secret_id     = aws_secretsmanager_secret.workload_key[each.key].id
  secret_string = temporalcloud_apikey.workload[each.key].token
}

output "namespace_ids" {
  description = "Map of domain → full Temporal namespace ID (e.g. nuon-<install>-orgs.<account>)."
  value       = { for d, _ in local.namespaces : d => temporalcloud_namespace.ns[d].namespace_id }
}

output "namespace_endpoint" {
  description = "Temporal Cloud gRPC endpoint for API-key auth."
  value       = "${var.tc_region}.api.temporal.io:7233"
}

output "api_key_secret_arns" {
  description = "Map of domain → AWS Secrets Manager ARN holding that namespace's workload API key."
  value       = { for d, _ in local.namespaces : d => aws_secretsmanager_secret.workload_key[d].arn }
}
