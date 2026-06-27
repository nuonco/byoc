locals {
  org_id = data.aws_organizations_organization.orgs.id
  public_prefixes = [
    "templates/*",
    "stacks/*",
  ]
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  provider = aws.current

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = ["arn:aws:s3:::${local.install_templates_bucket_name}", ]
    principals {
      type        = "AWS"
      identifiers = ["*", ]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [local.org_id]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:*Object",
    ]
    resources = ["arn:aws:s3:::${local.install_templates_bucket_name}/*", ]
    principals {
      type        = "AWS"
      identifiers = ["*", ]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [local.org_id]
    }
  }

  // allow a few select public paths in the artifacts bucket
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = formatlist("arn:aws:s3:::${local.install_templates_bucket_name}/%s", local.public_prefixes)
    principals {
      type        = "*"
      identifiers = ["*", ]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${local.install_templates_bucket_name}",
    ]
    principals {
      type        = "*"
      identifiers = ["*", ]
    }
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = local.public_prefixes
    }
  }

  # TLS protections — previously injected by the module's
  # attach_deny_insecure_transport_policy / attach_require_latest_tls_policy.
  # Replicated here because we now manage the bucket policy outside the module
  # (a bucket has a single policy), so these must live in the same document.
  statement {
    sid    = "denyInsecureTransport"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      "arn:aws:s3:::${local.install_templates_bucket_name}",
      "arn:aws:s3:::${local.install_templates_bucket_name}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*", ]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false", ]
    }
  }

  statement {
    sid    = "denyOutdatedTLS"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      "arn:aws:s3:::${local.install_templates_bucket_name}",
      "arn:aws:s3:::${local.install_templates_bucket_name}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*", ]
    }
    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2", ]
    }
  }
}

module "install_template_bucket" {
  providers = {
    aws = aws.current
  }

  source  = "terraform-aws-modules/s3-bucket/aws"
  version = ">= v4.9.0"

  bucket = local.install_templates_bucket_name
  versioning = {
    enabled = true
  }

  block_public_acls       = false
  block_public_policy     = false
  restrict_public_buckets = false
  ignore_public_acls      = false

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  # The bucket policy is managed outside the module (below) so it can be applied
  # only AFTER the public access block has propagated — otherwise PutBucketPolicy
  # races BlockPublicPolicy on a freshly created bucket and 403s. The deny-
  # insecure-transport / require-latest-tls statements the module would normally
  # add are folded into that external policy document.
  attach_policy = false
}

# Give the bucket's public access block (block_public_policy = false) time to
# propagate before attaching the public policy. Without this, PutBucketPolicy
# can run before the relaxed BPA takes effect and fail with AccessDenied
# (BlockPublicPolicy) on a newly created bucket.
resource "time_sleep" "wait_for_templates_public_access_block" {
  depends_on      = [module.install_template_bucket]
  create_duration = "30s"
}

resource "aws_s3_bucket_policy" "install_templates" {
  provider = aws.current

  bucket = module.install_template_bucket.s3_bucket_id
  policy = data.aws_iam_policy_document.s3_bucket_policy.json

  depends_on = [time_sleep.wait_for_templates_public_access_block]
}
