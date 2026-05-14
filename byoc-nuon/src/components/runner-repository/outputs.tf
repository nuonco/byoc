output "runner_repository" {
  value = {
    name           = aws_ecrpublic_repository.runner.repository_name
    arn            = aws_ecrpublic_repository.runner.arn
    registry_id    = aws_ecrpublic_repository.runner.registry_id
    repository_uri = aws_ecrpublic_repository.runner.repository_uri
  }
}

# convenience: the image url to feed into `runner_image_url`-style inputs
output "runner_image_url" {
  value = aws_ecrpublic_repository.runner.repository_uri
}
