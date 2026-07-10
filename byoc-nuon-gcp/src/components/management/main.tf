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

locals {
  gar_url_parts       = split("/", var.gar_repository_url)
  gar_location        = trimsuffix(local.gar_url_parts[0], "-docker.pkg.dev")
  gar_repository_name = local.gar_url_parts[2]
}

# Shared org-runner SA (stack-created): push/pull on the management repo only.
resource "google_artifact_registry_repository_iam_member" "org_runner_writer" {
  project    = var.project_id
  location   = local.gar_location
  repository = local.gar_repository_name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.org_runner_service_account_email}"
}
