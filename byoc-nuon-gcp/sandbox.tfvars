enable_linkerd = false

maintenance_recurring_window = {
  start_time = "2026-01-03T06:00:00Z"
  end_time   = "2026-01-04T06:00:00Z"
  recurrence = "FREQ=WEEKLY;BYDAY=SA"
}

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
