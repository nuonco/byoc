provider "aws" {
  region = var.region
}

provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["--region", var.region, "eks", "get-token", "--cluster-name", var.cluster_name]
  }

}
