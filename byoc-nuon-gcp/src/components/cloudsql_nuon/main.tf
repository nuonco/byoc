resource "google_sql_database_instance" "nuon" {
  project          = var.project_id
  name             = "nuon-${var.install_id}"
  region           = var.region
  database_version = "POSTGRES_15"

  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = "REGIONAL"
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_self_link
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    user_labels = {
      "install-nuon-co-id"     = var.install_id
      "component-nuon-co-name" = "cloudsql-nuon"
    }
  }
}

resource "google_sql_database" "nuonadmin" {
  project  = var.project_id
  instance = google_sql_database_instance.nuon.name
  name     = "nuonadmin"
}

resource "google_sql_user" "nuon" {
  project         = var.project_id
  instance        = google_sql_database_instance.nuon.name
  name            = "nuon"
  password        = random_password.nuon_db_password.result
  deletion_policy = "ABANDON"
}

resource "random_password" "nuon_db_password" {
  length  = 32
  special = false
}
