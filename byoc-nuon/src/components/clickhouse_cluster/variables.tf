locals {
  tags = {
    environment = var.env
    Terraform   = "infra-clickhouse-${var.env}"
  }
  tables = [
    "ctl_api.otel_log_records",
    "ctl_api.runner_heart_beats",
    "ctl_api.runner_health_checks",
  ]
  cluster_pw_secret_arn = "clickhouse_cluster_pw_${var.install_id}"

}

variable "env" {
  type        = string
  description = "The environment to use"
}

variable "install_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "cluster_oidc_provider" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}

#
# bucket
#

variable "clickhouse_s3_bucket_id" {
  type = string
}

variable "clickhouse_role_arn" {
  type = string
}

#
# clickhouse
#

variable "cluster_image_repository" {
  type = string
}

variable "cluster_image_tag" {
  type = string
}

variable "keeper_image_repository" {
  type = string
}

variable "keeper_image_tag" {
  type = string
}
