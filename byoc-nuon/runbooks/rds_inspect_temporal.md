Inspects the **Temporal** RDS instance (`temporal-<install-id>`) and prints, in table format:

- a one-line summary: instance id, instance class, and the metric time window
- the instance configuration: class, engine/version, status, storage type, allocated / max-allocated GB, provisioned IOPS, storage throughput, Multi-AZ, AZ, Performance Insights flag, parameter group
- OS-level metrics from Performance Insights for the last hour at 60s resolution: CPU%, total / cached / used / available memory, used%, swap-out, and read / write / total IOPS

Use this to size the instance, spot CPU or memory pressure, and check IOPS/storage headroom before or after a Temporal incident.

> Performance Insights must be enabled on the instance for the OS metric table. If it is disabled, the instance configuration is still printed and the OS table is skipped with a note.
