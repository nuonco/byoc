terraform {
  required_version = ">= 1.3.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.4"
    }
    utils = {
      source  = "cloudposse/utils"
      version = ">= 0.17.23"
    }
  }
}
