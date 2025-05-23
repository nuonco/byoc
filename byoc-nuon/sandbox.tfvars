maintenance_role_eks_access_entry_policy_associations = {
  eks_admin = {
    policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
    access_scope = {
      type = "cluster"
    }
  }
  eks_view = {
    policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    access_scope = {
      type = "cluster"
    }
  }
}

additional_namespaces = [
  "temporal",
  "clickhouse",
  "ctl-api",
  "dashboard-ui",
]

additional_access_entry = {
  "ctl-api" = {
    principal_arn     = "arn:aws:iam::{{.nuon.install_stack.outputs.account_id}}:role/eks/eks-byoc-nuon-ctl-api-{{.nuon.install.id}}",
    kubernetes_groups = []
    policy_associations = {
      cluster_admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
      eks_admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  }
}
