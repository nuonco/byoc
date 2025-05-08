module "iam_eks_role" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version     = ">= 5.1.0"
  create_role = true

  role_name = "eks-byoc-nuon-dashboard-ui-${var.install_id}"
  role_path = "/eks/"

  cluster_service_accounts = {
    (var.cluster_name) = ["dashboard-ui:dashboard-ui", ]
  }

  role_policy_arns = {
    custom = aws_iam_policy.dashboard_ui.arn
  }
}
