# Proxy-only subnet required by internal HTTP(S) load balancers (gce-internal Ingress).
resource "google_compute_subnetwork" "proxy_only" {
  project       = var.project_id
  name          = "${var.install_id}-proxy-only"
  region        = var.region
  network       = var.network
  ip_cidr_range = "10.129.0.0/23"
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}
