# create a zone for the root domain provided by the vendor
resource "aws_route53_zone" "root" {
  name = var.nuon_dns_root_domain
}
