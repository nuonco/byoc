enable_linkerd = false

master_authorized_networks = [
  {
    cidr_block   = "10.128.0.0/16"
    display_name = "install-stack-vpc"
  },
]

additional_namespaces = [
  "temporal",
  "clickhouse",
  "ctl-api",
  "dashboard-ui",
]
