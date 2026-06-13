output "clickhouse_bucket" {
  value = {
    name = google_storage_bucket.clickhouse.name
    url  = google_storage_bucket.clickhouse.url
  }
}

output "blob_bucket" {
  value = {
    name     = google_storage_bucket.blob.name
    url      = google_storage_bucket.blob.url
    base_url = "https://storage.googleapis.com/${google_storage_bucket.blob.name}/"
  }
}

output "install_template_bucket" {
  value = {
    name     = google_storage_bucket.install_templates.name
    url      = google_storage_bucket.install_templates.url
    base_url = "https://storage.googleapis.com/${google_storage_bucket.install_templates.name}/"
  }
}
