resource "kubectl_manifest" "namespace" {
  yaml_body = yamlencode({
    "apiVersion" = "v1"
    "kind"       = "Namespace"
    "metadata" = {
      # the metadata.name label is what the listener's networkPolicyPeers
      # namespaceSelector matches on for the ctl-api namespace
      "labels" = {
        "kubernetes.io/metadata.name" = local.namespace
        "name"                        = local.namespace
      }
      "name" = local.namespace
    }
  })
}
