# allows full access to generated rds cluster secrets and nuon generated secrets
# allows listing all secrets
data "aws_iam_policy_document" "service" {
  statement {
    sid    = "AllowSecretsManagerRDSScoped"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UpdateSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}::secret:rds!*",
    ]
  }
  statement {
    sid    = "AllowSecretsManagerNuonScoped"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UpdateSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}::secret:nuon-gen/*",
    ]
  }
  statement {
    sid    = "AllowListSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets"
    ]
    resources = ["*", ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "eks-policy-byoc-nuon-external-secrets-${var.install_id}"
  policy = data.aws_iam_policy_document.service.json
}
