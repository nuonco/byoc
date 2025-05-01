locals {
  external_secrets_manifests = toset([
    "https://raw.githubusercontent.com/external-secrets/external-secrets/${var.crd_version}/deploy/crds/bundle.yaml"
  ])
}

data "http" "external_secrets_crd_raw" {
  for_each = local.external_secrets_manifests
  url      = each.key
}

data "kubectl_file_documents" "external_secrets_crd_doc" {
  for_each = data.http.external_secrets_crd_raw
  content  = each.value.response_body
}
