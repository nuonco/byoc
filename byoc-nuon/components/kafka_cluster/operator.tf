#
# Strimzi cluster operator. Watches only its own namespace so it can't fight
# another operator over CRs elsewhere in the cluster.
#
# Lives in this component rather than a separate helm_chart component (the way
# crd_clickhouse_operator does) for two reasons: the CRs below must not be applied
# until the operator has installed its CRDs, and a depends_on inside one component
# is a far stronger ordering guarantee than component dependencies; and the chart
# wants the operator image split across registry/repository/name, which is much
# easier to do in HCL than in a values template. byoc's temporal component runs
# its helm_release the same way.
#
# Runs on the default nodepool, not the dedicated kafka one — it's a small
# control-plane pod that should stay freely reschedulable, and the kafka nodes are
# tainted and configured never to be disrupted.
#
# Strimzi does not support skipping minor versions on upgrade — go one at a time.
#
resource "helm_release" "strimzi" {
  namespace = local.namespace

  name       = "strimzi"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = var.operator_version

  values = [
    yamlencode({
      watchNamespaces = [local.namespace]
      resources       = var.operator_resources

      # Mirrored image. defaultImageRegistry/defaultImageRepository are
      # deliberately left alone: they would rewrite every STRIMZI_DEFAULT_*_IMAGE
      # under a single repo path, which does not match one-repo-per-mirrored-image.
      # Every image we actually use is pinned explicitly — the operator here, and
      # the broker / exporter / user operator on the Kafka CR.
      image = {
        registry   = local.operator_registry
        repository = local.operator_repository
        name       = local.operator_name
        tag        = var.strimzi_operator_image_tag
      }
    })
  ]

  # A 2-segment ref would leave operator_repository empty and silently fall back
  # to the chart's defaultImageRepository (strimzi), producing a quay.io-shaped
  # path against the mirrored registry. Every real registry path (ECR, GAR) has at
  # least three segments, so fail loudly instead.
  lifecycle {
    precondition {
      condition     = length(local.operator_ref_parts) >= 3
      error_message = "strimzi_operator_image_repository must be a registry-qualified path with at least 3 segments (host/path/name); got ${var.strimzi_operator_image_repository}."
    }
  }

  depends_on = [
    kubectl_manifest.namespace,
  ]
}
