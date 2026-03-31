resource "google_service_account" "dashboard_ui" {
  project      = var.project_id
  account_id   = "dashboard-ui-${substr(var.install_id, 0, 12)}"
  display_name = "dashboard-ui for ${var.install_id}"
}

resource "google_service_account_iam_member" "dashboard_ui_workload_identity" {
  service_account_id = google_service_account.dashboard_ui.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[dashboard-ui/dashboard-ui]"
}

resource "google_project_iam_member" "dashboard_ui_storage_reader" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.dashboard_ui.email}"
}
