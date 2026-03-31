# Cloud DNS zone for install-level DNS provisioning (nuon_dns feature).
resource "google_dns_managed_zone" "nuon_dns" {
  project     = var.project_id
  name        = "${var.install_id}-nuon-dns"
  dns_name    = "${var.nuon_dns_domain}."
  description = "Nuon DNS zone for install ${var.install_id}"

  labels = {
    "install-nuon-co-id"     = var.install_id
    "component-nuon-co-name" = "management"
  }
}

# Service account for GAR access — assumed by the ctl-api to push/pull images.
resource "google_service_account" "gar_access" {
  project      = var.project_id
  account_id   = "gar-access-${substr(var.install_id, 0, 16)}"
  display_name = "GAR access for ${var.install_id}"
}

resource "google_project_iam_member" "gar_admin" {
  project = var.project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.gar_access.email}"
}

resource "google_service_account_iam_member" "gar_workload_identity" {
  service_account_id = google_service_account.gar_access.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[ctl-api/ctl-api]"
}

# Service account for DNS management — used by ctl-api to provision DNS records for installs.
resource "google_service_account" "dns_access" {
  project      = var.project_id
  account_id   = "dns-mgmt-${substr(var.install_id, 0, 17)}"
  display_name = "DNS management for ${var.install_id}"
}

resource "google_project_iam_member" "dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.dns_access.email}"
}

resource "google_service_account_iam_member" "dns_workload_identity" {
  service_account_id = google_service_account.dns_access.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[ctl-api/ctl-api]"
}
