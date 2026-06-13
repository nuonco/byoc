variable "region" {
  type = string
}

variable "install_id" {
  type = string
}

variable "org_id" {
  type = string
}

variable "app_id" {
  type = string
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster. Defaults to n-<install_id> via stack.toml vars."
}

variable "root_domain" {
  type = string
}

variable "nuon_dns_domain" {
  type        = string
  description = "The Nuon DNS root domain for install DNS provisioning."
}

variable "enable_nuon_dns" {
  type    = bool
  default = true
}

# Passthrough from the parent install stack's VPC nested stack.
variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "runner_subnet_id" {
  type = string
}

locals {
  tags = {
    "install.nuon.co/id" = var.install_id
    "org.nuon.co/id"     = var.org_id
    "app.nuon.co/id"     = var.app_id
  }
  cloud_map_namespace = "nuon-byoc.local"
}
