variable "region" {
  type = string
}

variable "install_id" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "app_gateway_ssl_certificate_name" {
  description = "Optional certificate name already installed on the AKS-managed Application Gateway."
  type        = string
  default     = ""
}
