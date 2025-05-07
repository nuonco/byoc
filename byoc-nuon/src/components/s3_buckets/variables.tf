locals {
  install_templates_bucket_name = "${var.install_name}-byoc-nuon-install-templates"
  tags = {
    "install.nuon.co/id"     = var.nuon_install_id
    "component.nuon.co/name" = "s3_buckets"
  }
}

variable "install_name" {
  type = string
}

variable "region" {
  type = string
}

variable "nuon_install_id" {
  type = string
}
