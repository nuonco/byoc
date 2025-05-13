module "iam_eks_role" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version     = ">= 5.1.0"
  create_role = true

  role_name = "eks-byoc-nuon-external-secrets-${var.install_id}"
  role_path = "/eks/"

  cluster_service_accounts = {
    (var.cluster_name) = ["external-secrets:external-secrets", ]
  }

  role_policy_arns = {
    custom = aws_iam_policy.external_secrets.arn
  }
}

module "iam_eks_role_store" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version     = ">= 5.1.0"
  create_role = true

  role_name = "eks-byoc-nuon-external-secrets-store-${var.install_id}"
  role_path = "/eks/"

  cluster_service_accounts = {
    (var.cluster_name) = ["external-secrets:external-secrets", ]
  }

  role_policy_arns = {
    custom = aws_iam_policy.external_secrets.arn
  }
}
