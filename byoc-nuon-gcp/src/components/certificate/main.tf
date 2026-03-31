resource "google_certificate_manager_certificate" "wildcard" {
  project  = var.project_id
  name     = "${var.install_id}-wildcard"
  location = "global"

  managed {
    domains = [trimsuffix(var.domain_name, ".")]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.wildcard.id
    ]
  }

  labels = {
    "install-nuon-co-id" = var.install_id
  }
}

resource "google_certificate_manager_dns_authorization" "wildcard" {
  project  = var.project_id
  name     = "${var.install_id}-wildcard-auth"
  location = "global"
  domain   = trimsuffix(trimprefix(var.domain_name, "*."), ".")
}

resource "google_certificate_manager_certificate_map" "default" {
  project = var.project_id
  name    = "${var.install_id}-certmap"

  labels = {
    "install-nuon-co-id" = var.install_id
  }
}

resource "google_certificate_manager_certificate_map_entry" "wildcard" {
  project      = var.project_id
  name         = "${var.install_id}-wildcard"
  map          = google_certificate_manager_certificate_map.default.name
  certificates = [google_certificate_manager_certificate.wildcard.id]
  matcher      = "PRIMARY"
}

resource "google_dns_record_set" "cert_validation" {
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = google_certificate_manager_dns_authorization.wildcard.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.wildcard.dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [google_certificate_manager_dns_authorization.wildcard.dns_resource_record[0].data]
}
