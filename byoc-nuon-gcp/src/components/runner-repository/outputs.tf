locals {
  # GAR nests images inside a repository, where ECR Public treats "<install>/runner"
  # as the repository itself. The extra path segment keeps the pullable reference the
  # same shape as the AWS one, so the runner_image_url input is interchangeable.
  repository_url = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.runner.repository_id}"
  repository_uri = "${local.repository_url}/runner"
}

output "runner_repository" {
  value = {
    name           = google_artifact_registry_repository.runner.name
    id             = google_artifact_registry_repository.runner.id
    location       = google_artifact_registry_repository.runner.location
    repository_url = local.repository_url
    repository_uri = local.repository_uri
  }
}

# convenience: the image url to feed into `runner_image_url`-style inputs
output "runner_image_url" {
  value = local.repository_uri
}
