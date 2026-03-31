# Explicit service named "clickhouse" so ctl-api can reliably reach the cluster.
# The operator-managed service (clickhouse-clickhouse) is not used — same pattern as AWS.
resource "kubectl_manifest" "clickhouse_service" {
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "kind"       = "Service"
    "metadata" = {
      "name"      = "clickhouse"
      "namespace" = "clickhouse"
    }
    "spec" = {
      "ports" = [
        {
          "name"       = "http"
          "port"       = 8123
          "protocol"   = "TCP"
          "targetPort" = 8123
        },
        {
          "name"       = "client"
          "port"       = 9000
          "protocol"   = "TCP"
          "targetPort" = 9000
        },
      ]
      "type" = "ClusterIP"
      "selector" = {
        "clickhouse.altinity.com/app"       = "chop"
        "clickhouse.altinity.com/chi"       = "clickhouse-installation"
        "clickhouse.altinity.com/namespace" = "clickhouse"
        "clickhouse.altinity.com/ready"     = "yes"
      }
    }
  })

  depends_on = [
    kubectl_manifest.clickhouse_installation,
  ]
}
