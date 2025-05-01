variable "crd_version" {
  type    = string
  default = "v0.16.1"
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
