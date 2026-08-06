locals {
  name      = "datadog-agent"
  namespace = "datadog"
  has_keys  = (var.datadog_api_key != "" && var.datadog_app_key != "")
  enabled   = local.has_keys
}

variable "datadog_api_key" {
  type = string
}

variable "network_monitoring_enabled" {
  type        = bool
  default     = false
  description = "Enable DNS and network metrics collection (system-probe DNS stats)."
}

variable "datadog_app_key" {
  type = string
}

variable "install_id" {
  type = string
}

variable "install_name" {
  type = string
}

variable "org_id" {
  type = string
}

variable "org_name" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}
