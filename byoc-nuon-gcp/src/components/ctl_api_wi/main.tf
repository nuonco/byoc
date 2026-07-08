resource "google_service_account" "ctl_api" {
  project      = var.project_id
  account_id   = "ctl-api-${substr(var.install_id, 0, 12)}"
  display_name = "ctl-api for ${var.install_id}"
}

resource "google_service_account_iam_member" "ctl_api_workload_identity" {
  service_account_id = google_service_account.ctl_api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[ctl-api/ctl-api]"
}

# Let the runner impersonate ctl-api (mint OIDC tokens as ctl-api). The S3
# install-templates role trust policy is scoped to ctl-api's SA, so the
# s3_bucket inspect action — which runs on the runner — must present a token
# minted as ctl-api to verify that federation path.
resource "google_service_account_iam_member" "runner_impersonate_ctl_api" {
  service_account_id = google_service_account.ctl_api.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.runner_service_account_email}"
}

resource "google_project_iam_member" "ctl_api_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.ctl_api.email}"
}

resource "google_project_iam_member" "ctl_api_cloudsql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.ctl_api.email}"
}

resource "google_sql_user" "ctl_api_iam" {
  project         = var.project_id
  instance        = var.cloudsql_instance_name
  name            = trimsuffix(google_service_account.ctl_api.email, ".gserviceaccount.com")
  type            = "CLOUD_IAM_SERVICE_ACCOUNT"
  deletion_policy = "ABANDON"
}

resource "google_project_iam_member" "ctl_api_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.ctl_api.email}"
}

resource "google_project_iam_member" "ctl_api_artifact_registry_admin" {
  project = var.project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.ctl_api.email}"
}

resource "google_project_iam_member" "ctl_api_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.ctl_api.email}"
}

# Required for org runner provisioning: ctl-api creates GCP service accounts
# and Workload Identity bindings for each org's runner.
resource "google_project_iam_member" "ctl_api_sa_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.ctl_api.email}"
}

resource "google_project_iam_member" "ctl_api_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.ctl_api.email}"
}

# Required for deploying org runner pods via Helm into the GKE cluster.
resource "google_project_iam_member" "ctl_api_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.ctl_api.email}"
}

# Required for signing GCS URLs (install stack template upload). Scoped to
# signing as itself — a project-level grant would let ctl-api mint tokens for
# any SA in the project, including deprovision.
resource "google_service_account_iam_member" "ctl_api_token_creator" {
  service_account_id = google_service_account.ctl_api.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.ctl_api.email}"
}
