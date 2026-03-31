output "service_account_email" {
  value = google_service_account.dashboard_ui.email
}

output "service_account_name" {
  value = google_service_account.dashboard_ui.name
}
