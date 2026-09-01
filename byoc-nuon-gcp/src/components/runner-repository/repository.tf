#
# Artifact Registry repository that hosts the Nuon runner image for this install.
#
# - Public: anyone can pull
# - Single project: the runner only
# - Tags are semvers (no cleanup policies trimming images here; semver tags are
#   immutable in spirit and we keep all historical versions)
#
resource "google_artifact_registry_repository" "runner" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.install_id}-runner"
  format        = "DOCKER"
  description   = "Nuon BYOC runner image. Tags are semver releases of the runner."

  labels = {
    "install-nuon-co-id"     = var.install_id
    "org-nuon-co-id"         = var.org_id
    "component-nuon-co-name" = "runner-repository"
    "tier-nuon-co"           = "infra"
  }
}

# What makes this the equivalent of AWS's ECR *Public* repository, and the reason
# the runner image cannot simply be mirrored into the install's shared registry:
# an install runner on AWS or Azure holds no GCP credentials, so the only way it
# can pull is anonymously. Granting allUsers on a dedicated repository keeps that
# blast radius to the one image, which is already public upstream.
#
# An org with domain-restricted sharing (constraints/iam.allowedPolicyMemberDomains)
# will reject this binding — see the component README before assuming the apply is
# broken.
resource "google_artifact_registry_repository_iam_member" "public_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.runner.location
  repository = google_artifact_registry_repository.runner.name
  role       = "roles/artifactregistry.reader"
  member     = "allUsers"
}
