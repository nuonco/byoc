data "aws_iam_policy_document" "service" {
  # TODO: revisit
  statement {
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:ListBucket",
    ]
    resources = ["*", ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:*Object",
    ]
    resources = ["*", ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*", ]
  }

  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = ["*", ]
  }
}

resource "aws_iam_policy" "dashboard_ui" {
  name   = "eks-policy-byoc-nuon-dashboard-ui-${var.install_id}"
  policy = data.aws_iam_policy_document.service.json
}
