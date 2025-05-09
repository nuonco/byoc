
#
# clickhouse installation
#

locals {
  username = jsondecode(data.aws_secretsmanager_secret_version.db_instance_password.secret_string).username
  password = jsondecode(data.aws_secretsmanager_secret_version.db_instance_password.secret_string).password
}

data "aws_secretsmanager_secret_version" "db_instance_password" {
  secret_id = var.clickhouse_reader_secret_arn
}

# configmap to bootstrap ctl_api database
#resource "kubectl_manifest" "clickhouse_installation_configmap_bootstrap" {
#  yaml_body = yamlencode({
#    "apiVersion" = "v1"
#    "kind"       = "ConfigMap"
#    "metadata" = {
#      "name"      = "bootstrap-configmap"
#      "namespace" = "clickhouse"
#    }
#    "data" = {
#      "01_create_databases.sh" = <<-EOT
#      #!/bin/bash
#      set -e
#      clickhouse client -n <<-EOSQL
#      CREATE DATABASE IF NOT EXISTS ctl_api ON CLUSTER 'simple';
#      EOSQL

#      EOT
#    }
#  })
#}

resource "kubectl_manifest" "clickhouse_installation" {
  # generated with tfk8s and the source below
  # https://github.com/Altinity/clickhouse-operator/blob/master/docs/quick_start.md
  # NOTE: uses toleration to deploy to the NodePool defined above
  # NOTE: uses topologySpreadConstraints to distribute pods across nodes

  yaml_body = yamlencode({
    "apiVersion" = "clickhouse.altinity.com/v1"
    "kind"       = "ClickHouseInstallation"
    "metadata" = {
      "name"      = "clickhouse-installation"
      "namespace" = "clickhouse"
    }
    "spec" = {
      "configuration" = {
        "users" = {
          "${local.username}/password_sha256_hex" = sha256(local.password)
          "${local.username}/networks/ip"         = ["0.0.0.0/0"]
        }
        "clusters" = [
          {
            "name" = "simple"
            "templates" = {
              "podTemplate"     = "clickhouse:${var.cluster_image_tag}"
              "serviceTemplate" = "clickhouse:${var.cluster_image_tag}"
            }
            "layout" = {
              "replicasCount" = 2
              "shardsCount"   = 1
            }
          },
        ]
        "settings" = {
          "logger/level"                    = "information"
          "logger/console"                  = true
          "prometheus/endpoint"             = "/metrics"
          "prometheus/port"                 = 9363
          "prometheus/metrics"              = true
          "prometheus/events"               = true
          "prometheus/asynchronous_metrics" = true
          "prometheus/status_info"          = true
          "max_concurrent_queries"          = 2500
        }
        # configure to use the zookeeper nodes
        "zookeeper" = {
          "nodes" = [
            { "host" : "chk-clickhouse-keeper-chk-simple-0-0.clickhouse.svc.cluster.local" },
            { "host" : "chk-clickhouse-keeper-chk-simple-0-1.clickhouse.svc.cluster.local" },
            { "host" : "chk-clickhouse-keeper-chk-simple-0-2.clickhouse.svc.cluster.local" },
          ]
        }
        # add a storage configuration config so we can write to s3. this disk will be used for backups (/backups).
        # https://clickhouse.com/docs/en/integrations/s3#managing-credentials
        # https://clickhouse.com/docs/en/integrations/s3#configure-clickhouse-to-use-the-s3-bucket-as-a-disk
        # https://clickhouse.com/docs/en/operations/backup#configuring-backuprestore-to-use-an-s3-endpoint
        "files" = {
          "config.d/disks.xml" = <<-EOT
          <clickhouse>
            <storage_configuration>
              <disks>
                <s3_disk>
                  <type>s3_plain</type>
                  <endpoint>https://${data.aws_s3_bucket.clickhouse.bucket_domain_name}/tables/</endpoint>
                  <use_environment_credentials>true</use_environment_credentials>
                  <metadata_path>/var/lib/clickhouse/disks/s3_disk/</metadata_path>
                </s3_disk>
                <s3_cache>
                  <type>cache</type>
                  <disk>s3_disk</disk>
                  <path>/var/lib/clickhouse/disks/s3_cache/</path>
                  <max_size>10Gi</max_size>
                </s3_cache>
              </disks>
              <policies>
                <s3_main>
                  <volumes>
                    <main>
                      <disk>s3_disk</disk>
                    </main>
                  </volumes>
                </s3_main>
              </policies>
            </storage_configuration>
          </clickhouse>
          EOT
          "config.d/s3.xml"    = <<-EOT
            <clickhouse>
              <s3>
                  <use_environment_credentials>true</use_environment_credentials>
              </s3>
            </clickhouse>
          EOT
        }
      }
      "defaults" = {
        "templates" = {
          "dataVolumeClaimTemplate" = "data-volume-template"
          "serviceTemplate"         = "clickhouse:${var.cluster_image_tag}"
        }
      }
      "templates" = {
        # we define a clusterServiceTemplates so we can set an internal-hostname for access via twingate
        "serviceTemplates" = [{
          "name" = "clickhouse:${var.cluster_image_tag}"
          # default type is ClusterIP
          "spec" = {
            "ports" = [
              {
                "name" = "http"
                "port" = 8123
              },
              {
                "name" = "client"
                "port" = 9000
              }
            ]
          }
        }]
        # we define a podTemplate to ensure the attributes for node pool selection are set
        # and so we can define the image_tag dynamically
        "podTemplates" = [{
          "name" = "clickhouse:${var.cluster_image_tag}"
          "imagePullPolicy" : "IfNotPresent"
          "metadata" = {}
          "spec" = {
            "nodeSelector" = {
              "pool.nuon.co" = "clickhouse-installation"
            }
            "affinity" = {
              "podAntiAffinity" = {
                "requiredDuringSchedulingIgnoredDuringExecution" = [
                  {
                    "labelSelector" = {
                      "matchLabels" = {
                        # NOTE(fd): this label is automatically applied by the CRD so we can assume it exists.
                        #           that is, however, an assumption
                        "clickhouse.altinity.com/chi" = "clickhouse-installation"
                      }
                    }
                    "topologyKey" = "kubernetes.io/hostname"
                  },
                  {
                    "labelSelector" = {
                      "matchLabels" = {
                        # NOTE(fd): this label is automatically applied by the CRD so we can assume it exists.
                        #           that is, however, an assumption
                        "clickhouse.altinity.com/chi" = "clickhouse-installation"
                      }
                    }
                    "topologyKey" = "topology.kubernetes.io/zone"
                  },
                ]
              }
            }
            "topologySpreadConstraints" = [
              # spread the pods across nodes.
              {
                "maxSkew"           = 1
                "topologyKey"       = "kubernetes.io/hostname"
                "whenUnsatisfiable" = "ScheduleAnyway"
                "labelSelector" = {
                  "matchLabels" = {
                    # NOTE(fd): this label is automatically applied by the CRD so we can assume it exists.
                    #           that is, however, an assumption
                    "clickhouse.altinity.com/chi" = "clickhouse-installation"
                  }
                }
              },
              # spread the pods across az:
              {
                "maxSkew"           = 1
                "topologyKey"       = "topology.kubernetes.io/zone"
                "whenUnsatisfiable" = "ScheduleAnyway"
                "labelSelector" = {
                  "matchLabels" = {
                    # NOTE(fd): this label is automatically applied by the CRD so we can assume it exists.
                    #           that is, however, an assumption
                    "clickhouse.altinity.com/chi" = "clickhouse-installation"
                  }
                }
              }
            ]
            "tolerations" = [{
              "key"      = "pool.nuon.co"
              "operator" = "Equal"
              "value"    = "clickhouse-installation"
              "effect"   = "NoSchedule"
            }]
            "containers" = [
              {
                "name"  = "clickhouse"
                "image" = "${var.cluster_image_repository}:${var.cluster_image_tag}"
                "env" = [{
                  "name"  = "CLICKHOUSE_ALWAYS_RUN_INITDB_SCRIPTS"
                  "value" = "true"
                }]
                "volumeMounts" = [
                  {
                    "name"      = "data-volume-template"
                    "mountPath" = "/var/lib/clickhouse"
                  },
                  # {
                  #   "name"      = "bootstrap-configmap-volume"
                  #   "mountPath" = "/docker-entrypoint-initdb.d"
                  # }
                ],
              }
            ]
            "volumes" = [
              {
                "name" = "bootstrap-configmap-volume"
                "configMap" = {
                  "name" : "bootstrap-configmap"
                }
              }
            ]
          }
        }]
        "volumeClaimTemplates" = [
          {
            "name" = "data-volume-template"
            "spec" = {
              "storageClassName" = "ebi"
              "accessModes" = [
                "ReadWriteOnce",
              ]
              "resources" = {
                "requests" = {
                  "storage" = "20Gi"
                }
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [
    kubectl_manifest.clickhouse_keeper_installation
  ]
}
