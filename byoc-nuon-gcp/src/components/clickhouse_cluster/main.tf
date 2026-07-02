# The ClickHouse cluster and keeper are deployed via the Altinity operator CRDs.

locals {
  labels = {
    "install-nuon-co-id"     = var.install_id
    "component-nuon-co-name" = "clickhouse-cluster"
  }
}

resource "kubectl_manifest" "clickhouse_installation" {
  yaml_body = yamlencode({
    apiVersion = "clickhouse.altinity.com/v1"
    kind       = "ClickHouseInstallation"
    metadata = {
      name      = "clickhouse-installation"
      namespace = "clickhouse"
    }
    spec = {
      defaults = {
        templates = {
          podTemplate             = "default"
          dataVolumeClaimTemplate = "data-volume-template"
        }
      }
      configuration = {
        clusters = [
          {
            name = "simple"
            layout = {
              shardsCount   = 1
              replicasCount = 2
            }
          }
        ]
        users = {
          "clickhouse/networks/ip" = ["0.0.0.0/0"]
          "clickhouse/password" = {
            "valueFrom" = {
              "secretKeyRef" = {
                "name" = "clickhouse-cluster-pw"
                "key"  = "value"
              }
            }
          }
          "clickhouse/profile" = "default"
        }
        "zookeeper" = {
          "nodes" = [
            { "host" : "chk-clickhouse-keeper-chk-simple-0-0.clickhouse.svc.cluster.local" },
            { "host" : "chk-clickhouse-keeper-chk-simple-0-1.clickhouse.svc.cluster.local" },
            { "host" : "chk-clickhouse-keeper-chk-simple-0-2.clickhouse.svc.cluster.local" },
          ]
        }
        settings = {
          "logger/level"                    = "warning"
          "logger/console"                  = true
          "prometheus/endpoint"             = "/metrics"
          "prometheus/port"                 = 9363
          "prometheus/metrics"              = true
          "prometheus/events"               = true
          "prometheus/asynchronous_metrics" = true
          "prometheus/status_info"          = true
          "max_concurrent_queries"          = 2500
        }
        "files" = {
          "config.d/z_log_disable.xml" = <<-EOT
          <clickhouse>
              <asynchronous_metric_log remove="1"/>
              <backup_log remove="1"/>
              <error_log remove="1"/>
              <metric_log remove="1"/>
              <query_metric_log remove="1"/>
              <query_thread_log remove="1" />
              <query_log remove="1" />
              <query_views_log remove="1" />
              <part_log remove="1"/>
              <session_log remove="1"/>
              <text_log remove="1" />
              <trace_log remove="1"/>
              <crash_log remove="1"/>
              <opentelemetry_span_log remove="1"/>
              <zookeeper_log remove="1"/>
              <processors_profile_log remove="1"/>
              <latency_log remove="1"/>
          </clickhouse>
          EOT
        }
      }
      templates = {
        podTemplates = [
          {
            name = "default"
            spec = {
              # never co-locate the two replicas on the same node, and best-effort
              # spread them across zones. the label is applied automatically by the CRD.
              # pin onto the dedicated clickhouse-installation node pool (created by the
              # clickhouse_nodepools component) via its pool.nuon.co taint/label, mirroring AWS.
              nodeSelector = {
                "pool.nuon.co" = "clickhouse-installation"
              }
              tolerations = [{
                key      = "pool.nuon.co"
                operator = "Equal"
                value    = "clickhouse-installation"
                effect   = "NoSchedule"
              }]
              affinity = {
                podAntiAffinity = {
                  requiredDuringSchedulingIgnoredDuringExecution = [
                    {
                      labelSelector = {
                        matchLabels = {
                          "clickhouse.altinity.com/chi" = "clickhouse-installation"
                        }
                      }
                      topologyKey = "kubernetes.io/hostname"
                    }
                  ]
                }
              }
              topologySpreadConstraints = [
                {
                  maxSkew           = 1
                  topologyKey       = "topology.kubernetes.io/zone"
                  whenUnsatisfiable = "ScheduleAnyway"
                  labelSelector = {
                    matchLabels = {
                      "clickhouse.altinity.com/chi" = "clickhouse-installation"
                    }
                  }
                }
              ]
              containers = [
                {
                  name  = "clickhouse"
                  image = "${var.cluster_image_repository}:${var.cluster_image_tag}"
                  volumeMounts = [
                    {
                      name      = "data-volume-template"
                      mountPath = "/var/lib/clickhouse"
                    }
                  ]
                }
              ]
            }
          }
        ]
        volumeClaimTemplates = [
          {
            name = "data-volume-template"
            spec = {
              storageClassName = "ssd"
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "20Gi"
                }
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [
    kubectl_manifest.clickhouse_keeper_installation,
  ]
}
