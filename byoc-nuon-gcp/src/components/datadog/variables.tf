locals {
  name            = "datadog-agent"
  namespace       = "datadog"
  datadog_enabled = lower(var.datadog_enabled) == "true"
  has_keys        = (var.datadog_api_key != "" && var.datadog_app_key != "")
  enabled         = local.datadog_enabled && local.has_keys
}

variable "datadog_enabled" {
  type    = string
  default = "false"

  validation {
    condition     = !(lower(var.datadog_enabled) == "true" && var.datadog_api_key == "")
    error_message = "datadog_enabled is true but datadog_api_key is not set."
  }

  validation {
    condition     = !(lower(var.datadog_enabled) == "true" && var.datadog_app_key == "")
    error_message = "datadog_enabled is true but datadog_app_key is not set."
  }
}

variable "datadog_api_key" {
  type = string
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
