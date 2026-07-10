# SA is created by the install stack (permissions/dashboard_ui.toml); this
# component only attaches the workload-identity binding.
resource "google_service_account_iam_member" "dashboard_ui_workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[dashboard-ui/dashboard-ui]"
}
