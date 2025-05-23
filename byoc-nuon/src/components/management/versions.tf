terraform {
  required_version = ">= 1.11.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.94.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.36.0"
    }
  }
}
