# Cloud DNS zone for install-level DNS provisioning (nuon_dns feature). GAR
# and DNS access run under the stack-created ctl-api SA (permissions/
# ctl_api.toml), which carries the artifact-registry and dns permissions —
# the previous gar-access / dns-access service accounts are gone so component
# deploys never create SAs (commonly blocked by org IAM deny policies).
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
