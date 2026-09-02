locals {
  install_templates_bucket_name = "${var.install_id}-byoc-nuon-install-templates"

  # paths CloudFormation in the target AWS account(s) must be able to fetch by URL
  public_prefixes = [
    "templates/*",
    "stacks/*",
  ]

  tags = {
    "install.nuon.co/id"     = var.install_id
    "component.nuon.co/name" = "ctl-api-gcp-bucket"
    "service.nuon.co/name"   = "ctl-api"
  }
}

variable "install_id" {
  type        = string
  description = "Nuon install ID."
}

variable "region" {
  type        = string
  description = "AWS region for the install templates bucket."
}

variable "ctl_api_sa_unique_id" {
  type        = string
  description = <<-EOT
    Numeric unique_id of the GCP ctl-api service account
    (google_service_account.ctl_api.unique_id). Used as the `sub` claim in the
    web-identity trust policy so only that service account can assume the role.
  EOT
}
