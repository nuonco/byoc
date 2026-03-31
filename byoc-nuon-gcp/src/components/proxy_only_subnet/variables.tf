variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "install_id" {
  description = "Nuon install identifier."
  type        = string
}

variable "network" {
  description = "VPC network self link."
  type        = string
}
