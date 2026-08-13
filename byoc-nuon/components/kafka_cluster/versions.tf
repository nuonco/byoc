terraform {
  required_version = ">= 1.11.3"

  required_providers {
    # Pinned to 2.x: provider 3.0 dropped the `experiments` block and moved
    # `kubernetes` from a nested block to an attribute, so an unbounded constraint
    # silently resolves to a provider this config cannot configure.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "= 1.19"
    }
  }
}
