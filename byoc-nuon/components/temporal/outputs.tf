################################################################################
# Helm Release
################################################################################

# NOTE(jdt): this is always an apply behind :sob:
# output "manifests" {
#   value = helm_release.temporal.manifest
# }

output "frontend_url" {
  value = local.temporal.frontend_url
}

output "web_url" {
  value = local.temporal.web_url
}

output "image_tag" {
  value = local.temporal.image_tag
}

output "helm_version" {
  value = local.temporal.version
}
