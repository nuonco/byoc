locals {
  name      = "datadog-agent"
  namespace = "datadog"
  enabled   = (var.datadog_api_key != "" && var.datadog_app_key != "")
}

variable "datadog_api_key" {
  type        = string
  description = "The datadog api key - used by the agents."
}

variable "datadog_app_key" {
  type        = string
  description = "The datadog app key"
}

variable "install_id" {
  type        = string
  description = "Install ID"
}

variable "install_name" {
  type        = string
  description = "Install name"
}

variable "org_id" {
  type        = string
  description = "Organization ID"
}

variable "org_name" {
  type        = string
  description = "Organization Name"
}

# Cluster Info
variable "region" {
  type        = string
  description = "AWS Region"
}

variable "cluster_name" {
  type        = string
  description = "AWS EKS Cluster name"
}

variable "cluster_endpoint" {
  type        = string
  description = "AWS EKS Cluster Endpoint"
}

variable "cluster_certificate_authority_data" {
  type        = string
  description = "AWS EKS Cluster CA Data"
}
