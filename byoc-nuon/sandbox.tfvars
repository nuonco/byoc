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

      # Full Corefile override. EKS-managed CoreDNS does not support the
      # coredns-custom ConfigMap, so the entire Corefile must be supplied here.
      # This mirrors the EKS default Corefile and adds the `log` plugin so DNS
      # queries/failures are emitted to stdout and collected by the Datadog agent.
      corefile = <<-EOT
        .:53 {
            log
            errors
            health {
                lameduck 5s
            }
            ready
            kubernetes cluster.local in-addr.arpa ip6.arpa {
                pods insecure
                fallthrough in-addr.arpa ip6.arpa
            }
            prometheus :9153
            forward . /etc/resolv.conf
            cache 30
            loop
            reload
            loadbalance
        }
      EOT
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
