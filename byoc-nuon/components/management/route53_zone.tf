# create a zone for the root domain provided by the vendor
resource "aws_route53_zone" "root" {
  name = var.nuon_dns_domain

  # Records here are written by external-dns / cert-manager, not Terraform, and
  # a non-empty zone can't be deleted. Matches the sandbox zones.
  force_destroy = true
}
