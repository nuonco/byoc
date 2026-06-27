module "iam_eks_role" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version     = "5.1.0"
  create_role = true

  role_name = "eks-byoc-nuon-db-tools-${var.install_id}"
  role_path = "/eks/"

  cluster_service_accounts = {
    (var.cluster_name) = ["db-tools:db-tools"]
  }

  role_policy_arns = {
    db_access = aws_iam_policy.db_access.arn
  }
}
