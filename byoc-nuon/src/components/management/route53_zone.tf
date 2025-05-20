# create a zone for the root domain provided by the vendor
resource "aws_route53_zone" "root" {
  name = var.root_domain
}
