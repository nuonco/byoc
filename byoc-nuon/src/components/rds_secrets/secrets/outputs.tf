output "version_id" {
  value = data.aws_secretsmanager_secret_version.current.version_id
}

output "name" {
  value = resource.kubectl_manifest.secret.name
}

output "namespace" {
  value = resource.kubectl_manifest.secret.namespace
}

output "uuid" {
  value = resource.kubectl_manifest.secret.live_uid
}
