data "aws_iam_policy_document" "dns_access" {
  statement {
    effect = "Allow"
    // TODO: limite these as necessary
    actions = [
      "route53:*",
    ]
    // NOTE: this was historically "*"
    resources = ["*", ]
    # resources = [aws_route53_zone.root.arn, ]
  }
}

resource "aws_iam_policy" "dns_access_policy" {
  name   = "${var.install_id}-dns-access"
  policy = data.aws_iam_policy_document.dns_access.json
}

data "aws_iam_policy_document" "dns_access_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", ]

    principals {
      type = "AWS"
      identifiers = [
        var.ctl_api_role_arn
      ]
    }
  }
}

module "dns_access_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = ">= 5.1.0"

  create_role       = true
  role_requires_mfa = false

  role_name                       = "${var.install_id}-dns-access"
  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.dns_access_trust.json
  custom_role_policy_arns         = [aws_iam_policy.dns_access_policy.arn, ]
}
