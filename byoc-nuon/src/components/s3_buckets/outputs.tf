output "install_template_bucket" {
  value = {
    id          = module.install_template_bucket.s3_bucket_id
    arn         = module.install_template_bucket.s3_bucket_arn
    domain_name = module.install_template_bucket.s3_bucket_bucket_domain_name
    base_url    = "https://${module.install_template_bucket.s3_bucket_bucket_regional_domain_name}/"
    region      = module.install_template_bucket.s3_bucket_region
  }
}

output "clickhouse_bucket" {
  value = {
    id          = module.clickhouse_bucket.s3_bucket_id
    arn         = module.clickhouse_bucket.s3_bucket_arn
    domain_name = module.clickhouse_bucket.s3_bucket_bucket_domain_name
  }
}

output "clickhouse_bucket_role" {
  value = {
    arn = aws_iam_role.clickhouse_role.arn
  }
}
