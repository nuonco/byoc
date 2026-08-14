module "iam_eks_role" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version     = "5.1.0"
  create_role = true

  role_name = "eks-byoc-nuon-dashboard-ui-${var.install_id}"
  role_path = "/eks/"

  cluster_service_accounts = {
    (var.cluster_name) = ["dashboard-ui:dashboard-ui", ]
  }

  # No policies attached: the dashboard-ui service makes no AWS API calls. The
  # role exists only so the pod has an IRSA identity, and so the ARN can be
  # surfaced to the helm chart's service account annotation.
}
