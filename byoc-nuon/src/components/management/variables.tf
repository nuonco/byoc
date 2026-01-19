locals {
  nuon_dns = {
    is_valid = var.nuon_dns_domain != var.root_domain
  }
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "management"
  }
}

# basic details
variable "region" {
  type = string
}

variable "management_account_id" {
  type = string
}

variable "install_id" {
  type = string
}

variable "org_id" {
  type = string
}

# nuon dns
variable "root_domain" {
  type        = string
  description = "The Root Domain for this Nuon Install. Used only to ensure the same value is not being used for nuon dns and the root dns."
}

variable "nuon_dns_domain" {
  type        = string
  description = "The Nuon DNS root domain for install DNS provisioning. This value should differ from {{ .nuon.inputs.inputs.root_domain }}."
}

# cluster details (passthrough from the sandbox)
variable "cluster" {
  type = object({
    arn                        = string
    certificate_authority_data = string
    endpoint                   = string
    name                       = string
    platform_version           = string
    oidc_provider              = string
    oidc_provider_arn          = string
  })
  description = "EKS Cluster access details passed through from the sandbox."
}


variable "ecr" {
  type = object({
    id  = string
    arn = string
  })
  description = "ECR details passed through from the sandbox."
}

# service role arn
variable "ctl_api_role_arn" {
  type        = string
  description = "The role ARN for the CTL API k8s service account which will be allowed to assume the roles created here. "

}
