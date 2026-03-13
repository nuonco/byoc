variable "management_account_id" {
  type = string
}

variable "cluster" {
  type = object({
    certificate_authority_data = string
    endpoint                   = string
    name                       = string
    oidc_provider              = string
  })
  description = "Cluster access details passed through from the sandbox."
}

variable "acr" {
  type = object({
    id           = string
    login_server = string
  })
  description = "Azure Container Registry details passed through from the sandbox."
}

variable "dns_domain" {
  type = string
}

variable "dns_zone_id" {
  type = string
}

variable "dns_nameservers" {
  type    = list(string)
  default = []
}

variable "azure_tenant_id" {
  type        = string
  description = "Azure AD tenant ID for managed identity federation."
}

variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID."
}

variable "azure_resource_group" {
  type        = string
  description = "Azure resource group for org runner resources."
}

variable "azure_oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL from the AKS cluster for federated credentials."
}
