# AKS access for maintenance/break-glass is managed through Azure RBAC role
# assignments in the azure_rbac_access terraform component.

additional_namespaces = [
  "temporal",
  "clickhouse",
  "ctl-api",
  "dashboard-ui",
]
