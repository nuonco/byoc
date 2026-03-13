terraform {
  required_version = ">= 1.11.3"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "= 1.19"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.64.0"
    }
  }
}
