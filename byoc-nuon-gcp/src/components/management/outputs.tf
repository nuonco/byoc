output "dns_zone" {
  value = {
    nameservers = google_dns_managed_zone.nuon_dns.name_servers
    domain      = google_dns_managed_zone.nuon_dns.dns_name
    zone_id     = google_dns_managed_zone.nuon_dns.managed_zone_id
    name        = google_dns_managed_zone.nuon_dns.name
  }
}

output "cluster" {
  value = {
    name                       = var.cluster_name
    endpoint                   = var.cluster_endpoint
    certificate_authority_data = var.cluster_certificate_authority_data
    location                   = var.cluster_location
  }
}

output "gar" {
  value = {
    repository_url = var.gar_repository_url
  }
}
