variable "install_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "domain_name" {
  type        = string
  description = "Wildcard domain (e.g. *.example.com)."
}

variable "dns_zone_name" {
  type        = string
  description = "Cloud DNS managed zone name for cert validation."
}
