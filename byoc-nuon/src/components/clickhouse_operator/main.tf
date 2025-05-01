#
# Install Clickhouse Operator CRDs
#
locals {
  value_file = "${path.module}/values/values.yaml"
}

resource "helm_release" "altinity-operator" {
  namespace        = "kube-system"
  create_namespace = false

  name       = "clickhouse-operator"
  chart      = "clickhouse-operator/altinity-clickhouse-operator"
  repository = "https://docs.altinity.com/clickhouse-operator/"
  version    = "0.24.5"
  wait       = true

  # https://github.com/Altinity/clickhouse-operator/tree/master/deploy/helm/clickhouse-operator/
  values = [
    file(local.value_file),
  ]
}
