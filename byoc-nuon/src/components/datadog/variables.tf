locals {
  name      = "datadog-agent"
  namespace = "datadog"
  enabled   = (var.datadog_api_key != "" && var.datadog_app_key != "")
}

variable "env" {
  type        = string
  description = "The environment to use. Typically one of dev, stage, prod. In this case, the installation name."
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

