variable "operator_version" {
  type    = string
  default = "0.24.4"
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}
