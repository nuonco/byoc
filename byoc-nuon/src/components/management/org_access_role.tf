data "aws_iam_policy_document" "orgs_iam_access" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreatePolicy",
      "iam:CreateRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:TagPolicy",
      "iam:AttachRolePolicy",
      "iam:DeletePolicy",
      "iam:DeleteRole",
      "iam:DetachRolePolicy",
      # TODO: consider scoping to a prefix
      "ecr:*"
    ]
    resources = ["*", ]
  }
}

data "aws_iam_policy_document" "orgs_iam_access_trust" {

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

resource "aws_iam_policy" "orgs_iam_access_policy" {

  name   = "${var.install_id}-orgs-iam-access"
  policy = data.aws_iam_policy_document.orgs_iam_access.json
}

module "org_access_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = ">= 5.1.0"

  create_role       = true
  role_requires_mfa = false

  role_name                       = "${var.install_id}-orgs-iam-access"
  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.orgs_iam_access_trust.json
  custom_role_policy_arns         = [aws_iam_policy.orgs_iam_access_policy.arn, ]
}
