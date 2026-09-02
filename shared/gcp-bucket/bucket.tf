#
# Install templates bucket
#
# CloudFormation requires its templates to be served from S3, so even when the
# Nuon control plane runs on GCP, the install templates bucket must live in AWS.
# ctl-api (running on GKE) writes rendered templates here via the federated role
# below; CloudFormation in the target AWS account(s) reads them back by URL.
#
data "aws_iam_policy_document" "install_templates" {
  # public read on the template/stack prefixes so CloudFormation can fetch
  # rendered templates by URL.
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = formatlist("arn:aws:s3:::${local.install_templates_bucket_name}/%s", local.public_prefixes)
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.install_templates_bucket_name}"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = local.public_prefixes
    }
  }
}

module "install_template_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = ">= v4.9.0"

  bucket = local.install_templates_bucket_name
  versioning = {
    enabled = true
  }

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  attach_public_policy    = true
  block_public_acls       = false
  block_public_policy     = false
  restrict_public_buckets = false
  ignore_public_acls      = false

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  attach_policy = true
  policy        = data.aws_iam_policy_document.install_templates.json
}
