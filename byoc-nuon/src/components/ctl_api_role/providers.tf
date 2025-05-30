provider "aws" {
  region = var.region

  default_tags {
    tags = {
      "install.nuon.co/id"     = var.install_id
      "component.nuon.co/name" = "ctl-api-role"
      "service.nuon.co/name"   = "ctl-api"
    }
  }
}
