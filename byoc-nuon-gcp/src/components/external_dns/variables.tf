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

variable "cluster_endpoint" {
  description = "GKE cluster API endpoint."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "GKE cluster CA certificate (base64)."
  type        = string
}

variable "domain_filters" {
  description = "Comma-separated public domains external-dns is allowed to manage."
  type        = string
}

variable "internal_domain_filters" {
  description = "Comma-separated internal/private domains external-dns is allowed to manage."
  type        = string
}

variable "chart_version" {
  description = "external-dns Helm chart version."
  type        = string
  default     = "1.20.0"
}
