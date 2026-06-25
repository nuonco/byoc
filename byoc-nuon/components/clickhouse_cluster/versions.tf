terraform {
  required_version = ">= 1.11.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.67.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "= 1.19"
    }
    utils = {
      source  = "cloudposse/utils"
      version = "= 0.17.23"
    }
  }
}
