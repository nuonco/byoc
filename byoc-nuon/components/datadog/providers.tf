provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "component.nuon.co/name" = "datadog"
      "install.nuon.co/id"     = var.install_id
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.us5.datadoghq.com/"
}

provider "helm" {
  helm_driver = "configmap"

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
