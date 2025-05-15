data "aws_iam_policy_document" "ecr_iam_access" {
  # TODO: these permissions may be to elevated
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:DescribeImageScanFindings",
      "ecr:DescribeImages",
      "ecr:ListImages",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:DescribeRepositories",
      "ecr:GetRepositoryPolicy",
      "ecr:ListTagsForResource",
    ]
    resources = [var.ecr.arn, ]
  }
}

data "aws_iam_policy_document" "ecr_iam_access_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", ]

    principals {
      type = "AWS"
      identifiers = [
        var.ctl_api_role_arn,
      ]
    }
  }
}

resource "aws_iam_policy" "ecr_iam_access_policy" {
  name   = "${var.install_id}-ecr-iam-access"
  policy = data.aws_iam_policy_document.ecr_iam_access.json
}

module "ecr_access_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = ">= 5.1.0"

  create_role       = true
  role_requires_mfa = false

  role_name                       = "${var.install_id}-ecr-iam-access"
  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.ecr_iam_access_trust.json
  custom_role_policy_arns         = [aws_iam_policy.ecr_iam_access_policy.arn, ]
}
