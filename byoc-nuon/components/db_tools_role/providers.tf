provider "aws" {
  region = var.region

  default_tags {
    tags = {
      "install.nuon.co/id"     = var.install_id
      "component.nuon.co/name" = "db-tools-role"
      "service.nuon.co/name"   = "db-tools"
    }
  }
}
