variable "install_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "nuon_dns_domain" {
  type        = string
  description = "The Nuon DNS root domain for install DNS provisioning."
}

# Passthrough from sandbox
variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}

variable "cluster_location" {
  type = string
}

variable "gar_repository_url" {
  type = string
}

variable "org_runner_service_account_email" {
  type        = string
  description = "Stack-created shared org-runner SA (install stack custom_sa_emails output)."
}
