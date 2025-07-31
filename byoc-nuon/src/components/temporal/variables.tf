locals {
  service = "temporal"
  zone    = var.zone

  tags = {
    environment = var.env
    service     = local.service
    terraform   = "infra-temporal-${var.env}"
  }

  vars = yamldecode(data.utils_deep_merge_yaml.vars.output)
}

#

variable "env" {
  type        = string
  description = "The environment to use."
}

variable "region" {
  type = string
}

variable "zone" {
  type        = string
  description = "Internal Nuon DNS Domain name (not zone id). Used to construct domains (or it will be)."
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

# db details

variable "temporal_pw_secret_arn" {
  type        = string
  description = "The ARN  of the AWS Secret Manager Secret that holds the password for the temporal db user."
}

variable "temporal_visibility_pw_secret_arn" {
  type        = string
  description = "The ARN  of the AWS Secret Manager Secret that holds the username,password for the temporal_visibility_db user instance."
}

variable "db_instance_address" {
  type        = string
  description = "RDS Cluster Address"
}

variable "db_instance_port" {
  type        = string
  default     = "5432"
  description = "RDS Cluster Port"
}

# Images

variable "temporal_web_image_repository" {
  type        = string
  description = "Temporal web ui image repository"
}

variable "temporal_web_image_tag" {
  type        = string
  description = "Temporal web ui image tag"
}

variable "temporal_server_image_repository" {
  type        = string
  description = "Temporal server ui image repository"
}

variable "temporal_server_image_tag" {
  type        = string
  description = "Temporal server ui image tag"
}

variable "temporal_admin_tools_image_repository" {
  type        = string
  description = "Temporal admin_tools ui image repository"
}

variable "temporal_admin_tools_image_tag" {
  type        = string
  description = "Temporal admin_tools ui image tag"
}
