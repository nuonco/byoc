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

cluster_addons = {
  coredns = {
    configuration_values = {
      tolerations = [
        # Allows CoreDNS to run on the same nodes as the Karpenter controller
        # for use during cluster creation when Karpenter nodes do not yet exist
        #
        {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "NoSchedule"
        },
        {
          key : "CriticalAddonsOnly"
          value : "true"
          effect : "NoSchedule"
        },
      ]
    }
  }
  eks-pod-identity-agent = {}
  kube-proxy             = {}
  vpc-cni = {
    most_recent = true
    preserve    = true
    configuration_values = {
      env = {
        WARM_IP_TARGET    = "2"
        MINIMUM_IP_TARGET = "12"
        # ENABLE_PREFIX_DELEGATION = "true"
        # WARM_PREFIX_TARGET = "1"
      }
    }
  }
}
