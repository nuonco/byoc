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
          podTemplate = "default"
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
          "logger/level"   = "warning"
          "logger/console" = true
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
              containers = [
                {
                  name  = "clickhouse"
                  image = "${var.cluster_image_repository}:${var.cluster_image_tag}"
                }
              ]
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
