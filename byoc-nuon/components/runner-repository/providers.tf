locals {
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "runner-repository"
    "tier.nuon.co"           = "infra"
  }
}

# default provider is the install region. ECR Public is global but the
# api endpoint is only served from us-east-1, so we use a dedicated alias.
provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

# ECR Public api lives only in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = local.tags
  }
}
