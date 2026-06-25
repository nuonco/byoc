locals {
  datadog = {
    value_file = "values/datadog.yaml"
  }
}

resource "helm_release" "datadog" {
  count = local.enabled ? 1 : 0

  name             = local.name
  namespace        = local.namespace
  create_namespace = true

  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  version    = "3.54.2"

  values = [
    file(local.datadog.value_file),
    yamlencode({
      datadog = {
        apiKey = var.datadog_api_key
        tags = [
          "env:byoc",
          "install.id:${var.install_id}",
          "install.name:${var.install_name}",
          "org.id:${var.org_id}",
          "org.name:${var.org_name}",
        ]
        clusterName = var.cluster_name
      }
    })
  ]
}
