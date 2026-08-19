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

  # ctl-api assumes the management component's roles: MANAGEMENT_IAM_ROLE_ARN
  # (orgs IAM operations and ECR authorization) and DNS_MANAGEMENT_IAM_ROLE_ARN.
  # Scoped to those roles by name rather than "*" -- on "*" a compromised ctl-api
  # pod could assume the install's provision role, which holds AdministratorAccess.
  # The management component deploys after this one, so its outputs are not
  # available here; the names are deterministic from install_id.
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      format("arn:aws:iam::%s:role/%s-orgs-iam-access", data.aws_caller_identity.current.account_id, var.install_id),
      format("arn:aws:iam::%s:role/%s-dns-access", data.aws_caller_identity.current.account_id, var.install_id),
      format("arn:aws:iam::%s:role/%s-ecr-iam-access", data.aws_caller_identity.current.account_id, var.install_id),
    ]
  }
}

resource "aws_iam_policy" "ctl_api" {
  name   = "eks-policy-byoc-nuon-ctl-api-${var.install_id}"
  policy = data.aws_iam_policy_document.service.json
}
