#
# Federated role for ctl-api (running on GCP)
#
# ctl-api cannot hold AWS credentials on GCP. Instead its GCP service account
# mints a Google-signed OIDC token (audience=sts.amazonaws.com) from the
# metadata server and exchanges it for temporary AWS credentials via
# sts:AssumeRoleWithWebIdentity. `accounts.google.com` is a built-in AWS
# web-identity provider, so no aws_iam_openid_connect_provider is required.
#
data "aws_iam_policy_document" "ctl_api_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["accounts.google.com"]
    }

    # sub is the numeric unique_id of the ctl-api GCP service account, so only
    # that identity can assume this role. The GKE metadata server sets aud to
    # the SA's own unique_id rather than the requested audience, so we rely
    # on sub alone for binding.
    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:sub"
      values   = [var.ctl_api_sa_unique_id]
    }
  }
}

# bucket access granted to the assumed role
data "aws_iam_policy_document" "install_templates_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.install_templates_bucket_name}"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:*Object"]
    resources = ["arn:aws:s3:::${local.install_templates_bucket_name}/*"]
  }
}

resource "aws_iam_role" "ctl_api" {
  name               = "${var.install_id}-byoc-nuon-ctl-api-gcp"
  assume_role_policy = data.aws_iam_policy_document.ctl_api_trust.json

  inline_policy {
    name   = "${var.install_id}-byoc-nuon-install-templates-access"
    policy = data.aws_iam_policy_document.install_templates_access.json
  }

  tags = local.tags
}
