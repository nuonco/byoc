secrets = [
  {
    arn = "{{ .nuon.components.rds_cluster_nuon.outputs.db_instance_master_user_secret_arn }}"
    name = "nuon-db"
    namespace = "ctl-api"
  },
  {
    arn = "{{ .nuon.components.rds_cluster_temporal.outputs.db_instance_master_user_secret_arn }}"
    name = "temporal-db"
    namespace = "temporal"
  }
]
