provider "helm" {
  experiments {
    manifest = true
  }
}

provider "kubernetes" {}
