output "service_account_email" {
  value = google_service_account.ctl_api.email
}

output "service_account_name" {
  value = google_service_account.ctl_api.name
}

output "service_account_unique_id" {
  value = google_service_account.ctl_api.unique_id
}

output "db_user" {
  value = trimsuffix(google_service_account.ctl_api.email, ".gserviceaccount.com")
}
