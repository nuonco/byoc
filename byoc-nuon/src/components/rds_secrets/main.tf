locals {
  secrets = {
    namespaces = toset(var.secrets[*].namespace)
  }
}


resource "kubectl_manifest" "secret_namespaces" {
  for_each = local.secrets.namespaces

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = each.value
    }
  })
}


module "secrets" {
  for_each = {
    for index, secret in var.secrets :
    secret.arn => secret
  }

  source = "./secrets"

  arn       = each.value.arn
  name      = each.value.name
  namespace = each.value.namespace

  depends_on = [
    resource.kubectl_manifest.secret_namespaces
  ]
}
