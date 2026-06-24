locals {
  helm_ecr_registry_url = "oci://${trimprefix(data.aws_ecr_authorization_token.ecr_token.proxy_endpoint, "https://")}"
}

# this is the root account that the credentials have permissions for.
# use it to get list of accounts and pivot to the correct one
provider "aws" {
  region = var.region
  alias  = "mgmt"
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  region = local.vars.region
  alias  = "infra-shared-prod"

  default_tags {
    tags = local.tags
  }
}

provider "helm" {
  experiments {
    manifest = true
  }

  registry {
    url      = local.helm_ecr_registry_url
    username = data.aws_ecr_authorization_token.ecr_token.user_name
    password = data.aws_ecr_authorization_token.ecr_token.password
  }

  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "--region", var.region, "get-token", "--cluster-name", var.cluster_name]
    }
  }
}
