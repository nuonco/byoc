resource "google_storage_bucket" "clickhouse" {
  project  = var.project_id
  name     = "${var.install_id}-nuon-clickhouse"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = false
  }

  labels = {
    "install-nuon-co-id"     = var.install_id
    "component-nuon-co-name" = "clickhouse-backup"
  }
}

resource "google_storage_bucket" "install_templates" {
  project  = var.project_id
  name     = "${var.install_id}-byoc-nuon-install-templates"
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  labels = {
    "install-nuon-co-id"     = var.install_id
    "component-nuon-co-name" = "install-templates"
  }
}

resource "google_storage_bucket_iam_member" "install_templates_public_read" {
  bucket = google_storage_bucket.install_templates.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
