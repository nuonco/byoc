# this is the root account that the credentials have permissions for.
# use it to get list of accounts and pivot to the correct one
provider "aws" {
  region = var.region
}

provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "--region", var.region, "get-token", "--cluster-name", var.cluster_name]
  }
}
