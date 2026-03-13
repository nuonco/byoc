locals {
  # AGIC references certificates by the name already installed on Application Gateway.
  certificate_name = trimspace(var.app_gateway_ssl_certificate_name)
}
