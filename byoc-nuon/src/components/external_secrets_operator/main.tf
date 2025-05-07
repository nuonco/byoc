locals {
  all_manifests = merge([
    for src in data.kubectl_file_documents.external_secrets_crd_doc :
    src.manifests
  ]...)
}

resource "kubectl_manifest" "external_secrets_operator" {
  for_each  = local.all_manifests
  yaml_body = each.value
}
