# this is the root account that the credentials have permissions for.
# use it to get list of accounts and pivot to the correct one
provider "aws" {
  region = var.region
  default_tags {
    tags = merge(
      local.tags,
      {
        "tier.nuon.co" = "infra"
      }
    )
  }
}

provider "kubectl" {}
