resource "aws_route53_zone" "public" {
  count = var.enable_nuon_dns ? 1 : 0
  name  = var.nuon_dns_domain
}
