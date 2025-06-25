locals {
  backups = {
    tables = [
      "ctl_api.otel_log_records",
      # omitted
      # "ctl_api.runner_heart_beats",
      # "ctl_api.runner_health_checks",
    ]
  }
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
