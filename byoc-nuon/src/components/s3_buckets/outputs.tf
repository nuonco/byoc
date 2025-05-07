output "install_template_bucket" {
  value = {
    id          = module.bucket.s3_bucket_id
    arn         = module.bucket.s3_bucket_arn
    domain_name = module.bucket.s3_bucket_bucket_domain_name
  }
}
