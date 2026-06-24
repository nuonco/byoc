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

variable "project_id" {
  type = string
}

variable "clickhouse_bucket_name" {
  type        = string
  description = "Name of the GCS bucket used for ClickHouse backups."
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}

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
