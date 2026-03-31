variable "zone" {
  type        = string
  description = "Internal DNS domain for service discovery."
}

variable "codec_endpoint" {
  type = string
}

variable "ctl_api_host" {
  type = string
}

# DB
variable "db_instance_address" {
  type = string
}

variable "db_instance_port" {
  type    = string
  default = "5432"
}

variable "db_default_username" {
  type    = string
  default = "temporal"
}

variable "db_visibility_username" {
  type    = string
  default = "temporal_visibility"
}

# Images
variable "temporal_server_image_repository" {
  type = string
}

variable "temporal_server_image_tag" {
  type = string
}

variable "temporal_web_image_repository" {
  type = string
}

variable "temporal_web_image_tag" {
  type = string
}

variable "temporal_admin_tools_image_repository" {
  type = string
}

variable "temporal_admin_tools_image_tag" {
  type = string
}

# GKE cluster access
variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}
