# The ctl-api service account is created by the install stack (permissions/
# ctl_api.toml custom role) under the customer admin's identity, so component
# deploys never call iam.serviceAccounts.create — commonly blocked by org IAM
# deny policies. This component only attaches identity bindings to it.
locals {
  sa_resource = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
}

resource "google_service_account_iam_member" "ctl_api_workload_identity" {
  service_account_id = local.sa_resource
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[ctl-api/ctl-api]"
}

# Required for signing GCS URLs (install stack template upload). Scoped to
# signing as itself — a project-level grant would let ctl-api mint tokens for
# any SA in the project, including deprovision.
resource "google_service_account_iam_member" "ctl_api_token_creator" {
  service_account_id = local.sa_resource
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.service_account_email}"
}

resource "google_sql_user" "ctl_api_iam" {
  project         = var.project_id
  instance        = var.cloudsql_instance_name
  name            = trimsuffix(var.service_account_email, ".gserviceaccount.com")
  type            = "CLOUD_IAM_SERVICE_ACCOUNT"
  deletion_policy = "ABANDON"
}
