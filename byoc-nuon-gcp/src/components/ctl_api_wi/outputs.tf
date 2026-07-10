output "service_account_email" {
  value = var.service_account_email
}

output "db_user" {
  value = trimsuffix(var.service_account_email, ".gserviceaccount.com")
}
