locals {
  logLevel = "warning"
  backups = {
    tables = [
      "ctl_api.otel_log_records",
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
# backups
#

variable "clickhouse_storage_account_name" {
  type = string
}

variable "clickhouse_storage_container_name" {
  type = string
}

variable "clickhouse_storage_account_resource_group" {
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
