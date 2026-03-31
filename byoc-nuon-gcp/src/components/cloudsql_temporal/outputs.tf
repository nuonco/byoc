output "address" {
  value = google_sql_database_instance.temporal.private_ip_address
}

output "connection_name" {
  value = google_sql_database_instance.temporal.connection_name
}

output "db_instance_name" {
  value = google_sql_database_instance.temporal.name
}

output "db_instance_port" {
  value = "5432"
}

output "db_instance_username" {
  value = google_sql_user.temporaladmin.name
}

output "db_password" {
  value     = random_password.temporal_db_password.result
  sensitive = true
}

