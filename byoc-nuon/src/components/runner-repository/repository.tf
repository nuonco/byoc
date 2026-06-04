#
# Public ECR repository that hosts the Nuon runner image for this install.
#
# - Public: anyone can pull
# - Single project: the runner only
# - Tags are semvers (no lifecycle rules trimming images here; semver tags are
#   immutable in spirit and we keep all historical versions)
#
resource "aws_ecrpublic_repository" "runner" {
  provider = aws.us_east_1

  repository_name = "${var.install_id}/runner"

  catalog_data {
    about_text        = "Nuon BYOC runner image. Tags are semver releases of the runner."
    architectures     = ["x86-64", "ARM 64"]
    description       = "Nuon BYOC runner"
    operating_systems = ["Linux"]
    usage_text        = "Pull a specific semver tag, e.g. `vX.Y.Z`. The `latest` tag is not maintained."
  }
}
