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

secrets = [
  {
    arn = "{{ .nuon.actions.workflows.generate_ch_cluster_reader_secret.outputs.secret.ARN }}"
    name = "clickhouse-cluster-ro"
    namespace = "ctl-api"
  },
  {
    arn = "{{ .nuon.actions.workflows.generate_ch_cluster_secret.outputs.secret.ARN }}"
    name = "clickhouse-cluster"
    namespace = "ctl-api"
  },
  {
    arn = "{{ .nuon.actions.workflows.generate_ch_cluster_reader_secret.outputs.secret.ARN }}"
    name = "clickhouse-cluster-ro"
    namespace = "clickhouse"
  },
  {
    arn = "{{ .nuon.actions.workflows.generate_ch_cluster_secret.outputs.secret.ARN }}"
    name = "clickhouse-cluster"
    namespace = "clickhouse"
  },
  {
    arn = "{{ .nuon.actions.workflows.generate_ch_operator_secret.outputs.secret.ARN }}"
    name = "clickhouse-operator"
    namespace = "clickhouse"
  },
]
