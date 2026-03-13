data "azurerm_storage_account" "clickhouse_backups" {
  name                = var.clickhouse_storage_account_name
  resource_group_name = var.clickhouse_storage_account_resource_group
}

resource "kubectl_manifest" "clickhouse_backup_script" {
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "kind"       = "ConfigMap"
    "metadata" = {
      "name"      = "clickhouse-backup-to-blob-script"
      "namespace" = "clickhouse"
      "managed"   = "terraform"
    }
    "data" = {
      "backup.sh" = file("${path.module}/backup.sh")
    }
  })

  depends_on = [
    kubectl_manifest.clickhouse_installation,
  ]
}

resource "kubectl_manifest" "clickhouse_backup_storage_secret" {
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "kind"       = "Secret"
    "metadata" = {
      "name"      = "clickhouse-backup-blob-creds"
      "namespace" = "clickhouse"
    }
    "type" = "Opaque"
    "stringData" = {
      "AZURE_STORAGE_ACCOUNT_NAME" = var.clickhouse_storage_account_name
      "AZURE_STORAGE_ACCOUNT_KEY"  = data.azurerm_storage_account.clickhouse_backups.primary_access_key
    }
  })

  depends_on = [
    kubectl_manifest.clickhouse_installation,
  ]
}

resource "kubectl_manifest" "clickhouse_backup_crons" {
  for_each = toset(local.backups.tables)

  yaml_body = yamlencode({
    "apiVersion" = "batch/v1"
    "kind"       = "CronJob"
    "metadata" = {
      "name"      = "ch-azure-blob-backup-${replace(replace(each.key, "_", "-"), "ctl-api.", "")}"
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
                      "name"  = "BLOB_BACKUPS_URL"
                      "value" = "https://${data.azurerm_storage_account.clickhouse_backups.primary_blob_host}/${var.clickhouse_storage_container_name}/backups"
                    },
                    {
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
                      "name" = "AZURE_STORAGE_ACCOUNT_NAME"
                      "valueFrom" = {
                        "secretKeyRef" = {
                          "name" = "clickhouse-backup-blob-creds"
                          "key"  = "AZURE_STORAGE_ACCOUNT_NAME"
                        }
                      }
                    },
                    {
                      "name" = "AZURE_STORAGE_ACCOUNT_KEY"
                      "valueFrom" = {
                        "secretKeyRef" = {
                          "name" = "clickhouse-backup-blob-creds"
                          "key"  = "AZURE_STORAGE_ACCOUNT_KEY"
                        }
                      }
                    },
                  ]
                  "image"           = "${var.cluster_image_repository}:${var.cluster_image_tag}"
                  "imagePullPolicy" = "IfNotPresent"
                  "name"            = "ch-azure-blob-backup-${replace(replace(each.key, "_", "-"), "ctl-api.", "")}"
                  "volumeMounts" = [
                    {
                      "name"      = "config-volume"
                      "mountPath" = "/usr/local/bin/backup.sh"
                      "subPath"   = "backup.sh"
                    },
                  ]
                },
              ]
              "restartPolicy"      = "OnFailure"
              "serviceAccountName" = "default"
              "volumes" = [
                {
                  "configMap" = {
                    "name" = "clickhouse-backup-to-blob-script"
                  }
                  "name" = "config-volume"
                },
              ]
            }
          }
        }
      }
      "schedule"                   = "*/15 * * * *"
      "successfulJobsHistoryLimit" = 0
      "failedJobsHistoryLimit"     = 0
    }
  })

  depends_on = [
    kubectl_manifest.clickhouse_backup_script,
    kubectl_manifest.clickhouse_backup_storage_secret,
  ]
}
