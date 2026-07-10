// clickhouse GCS backup crons
// docs: https://clickhouse.com/docs/en/operations/backup#configuring-backuprestore-to-use-an-s3-endpoint
//
// NOTE: GCS does not support the S3 environment-credential flow that the AWS install relies on
// (IRSA + use_environment_credentials). Instead we authenticate to the bucket over the GCS
// interoperability (S3-compatible XML) API using an HMAC key, passed inline to the BACKUP command.

// SA is created by the install stack (permissions/clickhouse_backup.toml);
// only its HMAC key and bucket grant are managed here.

// grant the backup SA read/write on the clickhouse backup bucket only.
resource "google_storage_bucket_iam_member" "clickhouse_backup" {
  bucket = var.clickhouse_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.backup_service_account_email}"
}

// HMAC key used by ClickHouse's S3 client to talk to GCS.
resource "google_storage_hmac_key" "clickhouse_backup" {
  project               = var.project_id
  service_account_email = var.backup_service_account_email
}

// sync the HMAC credentials into the clickhouse namespace as a k8s secret.
resource "kubectl_manifest" "clickhouse_backup_hmac_secret" {
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "kind"       = "Secret"
    "metadata" = {
      "name"      = "clickhouse-backup-hmac"
      "namespace" = "clickhouse"
      "managed"   = "terraform"
    }
    "type" = "Opaque"
    "stringData" = {
      "access_key" = google_storage_hmac_key.clickhouse_backup.access_id
      "secret_key" = google_storage_hmac_key.clickhouse_backup.secret
    }
  })
  depends_on = [
    kubectl_manifest.clickhouse_installation
  ]
}

resource "kubectl_manifest" "clickhouse_backup_script" {
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "kind"       = "ConfigMap"
    "metadata" = {
      "name"      = "clickhouse-backup-to-gcs-script"
      "namespace" = "clickhouse"
      "managed"   = "terraform"
    }
    "data" = {
      "backup.sh" = file("${path.module}/backup.sh")
    }
  })
  depends_on = [
    kubectl_manifest.clickhouse_installation
  ]
}

// we make a cron for each of the tables in locals.backups.tables
// TODO(fd): running n crons where n = len(locals.backups.tables) is likely to tax the db as we grow.
// consider making this a job and triggering it via ctl-api or some other process w/ insight
// into the state of these tables so the system can choose when to back itself up. this would mean we
// would backup more often during on-hours and less during off-hours, presumably saving resources.
resource "kubectl_manifest" "clickhouse_backup_crons" {
  for_each = toset(local.backups.tables)

  yaml_body = yamlencode({
    "apiVersion" = "batch/v1"
    "kind"       = "CronJob"
    "metadata" = {
      "name"      = "ch-gcs-backup-${replace(replace(each.key, "_", "-"), "ctl-api.", "")}"
      "namespace" = "clickhouse"
      "annotations" = {
        "nuon.clickhouse.io/table" = replace(replace(each.key, "_", "-"), "ctl-api.", "")
      }
    }
    "spec" = {
      "jobTemplate" = {
        "spec" = {
          "template" = {
            "spec" = {
              "containers" = [
                {
                  "command" = [
                    "bash",
                    "/usr/local/bin/backup.sh",
                    each.key,
                  ]
                  "env" = [
                    {
                      "name"  = "BUCKET_URL"
                      "value" = "https://storage.googleapis.com/${var.clickhouse_bucket_name}"
                    },
                    {
                      // this is the service url
                      "name"  = "CLICKHOUSE_URL"
                      "value" = "clickhouse.clickhouse.svc.cluster.local"
                    },
                    {
                      "name"  = "CLICKHOUSE_USERNAME"
                      "value" = "clickhouse"
                    },
                    {
                      "name" = "CLICKHOUSE_PASSWORD"
                      "valueFrom" = {
                        "secretKeyRef" = {
                          "name" = "clickhouse-cluster-pw"
                          "key"  = "value"
                        }
                      }
                    },
                    {
                      "name" = "S3_ACCESS_KEY"
                      "valueFrom" = {
                        "secretKeyRef" = {
                          "name" = "clickhouse-backup-hmac"
                          "key"  = "access_key"
                        }
                      }
                    },
                    {
                      "name" = "S3_SECRET_KEY"
                      "valueFrom" = {
                        "secretKeyRef" = {
                          "name" = "clickhouse-backup-hmac"
                          "key"  = "secret_key"
                        }
                      }
                    },
                  ]
                  "image"           = "${var.cluster_image_repository}:${var.cluster_image_tag}"
                  "imagePullPolicy" = "IfNotPresent"
                  "name"            = "ch-gcs-backup-${replace(replace(each.key, "_", "-"), "ctl-api.", "")}"
                  "volumeMounts" = [
                    {
                      "name"      = "config-volume"
                      "mountPath" = "/usr/local/bin/backup.sh"
                      "subPath" : "backup.sh"
                    },
                  ]
                },
              ]
              "restartPolicy"      = "OnFailure"
              "serviceAccountName" = "default"
              "volumes" = [
                {
                  "configMap" = {
                    "name" = "clickhouse-backup-to-gcs-script"
                  }
                  "name" = "config-volume"
                },
              ]
            }
          }
        }
      }
      "schedule"                   = "*/30 * * * *"
      "successfulJobsHistoryLimit" = 0
      "failedJobsHistoryLimit"     = 0
    }
  })

  depends_on = [
    kubectl_manifest.clickhouse_installation,
    kubectl_manifest.clickhouse_backup_hmac_secret,
    kubectl_manifest.clickhouse_backup_script,
  ]
}
