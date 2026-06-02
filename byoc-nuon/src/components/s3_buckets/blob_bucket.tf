locals {
  blob_bucket_name = "${var.install_id}-nuon-blob"
}

# Blob storage bucket for the ctl-api Temporal callback + data converter, which
# offloads large workflow payloads to S3. Mirrors the `nuon-blob` bucket in prod.
module "blob_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = ">= v4.9.0"

  bucket = local.blob_bucket_name
  versioning = {
    enabled = true
  }

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true
  attach_public_policy                  = false

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
}
