terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags { tags = local.tags }
}

variable "region" { type = string }
variable "install_id" { type = string }
variable "org_id" { type = string }

locals {
  tags = {
    "install.nuon.co/id"     = var.install_id
    "org.nuon.co/id"         = var.org_id
    "component.nuon.co/name" = "s3-buckets"
  }
  buckets = {
    blob              = "n-${var.install_id}-blob"
    install_templates = "n-${var.install_id}-install-templates"
    clickhouse_backup = "n-${var.install_id}-clickhouse-backup"
  }
}

resource "aws_s3_bucket" "this" {
  for_each      = local.buckets
  bucket        = each.value
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "install_templates" {
  bucket = aws_s3_bucket.this["install_templates"].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = aws_s3_bucket.this
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "clickhouse_backup" {
  bucket = aws_s3_bucket.this["clickhouse_backup"].id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"
    filter {}
    expiration { days = 14 }
  }
}

output "blob_bucket" { value = aws_s3_bucket.this["blob"].id }
output "install_templates_bucket" { value = aws_s3_bucket.this["install_templates"].id }
output "clickhouse_backup_bucket" { value = aws_s3_bucket.this["clickhouse_backup"].id }
output "blob_bucket_arn" { value = aws_s3_bucket.this["blob"].arn }
output "install_templates_bucket_arn" { value = aws_s3_bucket.this["install_templates"].arn }
output "clickhouse_backup_bucket_arn" { value = aws_s3_bucket.this["clickhouse_backup"].arn }
