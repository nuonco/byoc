resource "aws_eks_access_entry" "ctl_api" {
  cluster_name  = var.cluster_name
  principal_arn = module.iam_eks_role.iam_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "ctl_api_eks_cluster_admin" {
  cluster_name  = var.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = module.iam_eks_role.iam_role_arn

  access_scope {
    type = "cluster"
  }
}
