Inspects both RDS instances (**ctl-api** and **Temporal**) and prints, in table
format:

- a one-line summary: instance id, instance class, and the metric time window
- the instance configuration: class, engine/version, status, storage type,
  allocated / max-allocated GB, provisioned IOPS, storage throughput, Multi-AZ,
  AZ, Performance Insights flag, parameter group
- the storage utilization table: allocated / free / used GB and used %
- OS-level metrics from Performance Insights for the last hour at 60s
  resolution: CPU%, **AAS** (average active sessions), total / cached / used /
  available memory, memory used%, swap-out, read / write / total IOPS, disk
  read/write throughput (MB/s), and network rx/tx (MB/s)
- an AAS breakdown over the last hour (ranked tables): **by wait event**,
  **by query** (tokenized SQL), and **by lock wait**

Use this to size an instance, spot CPU or memory pressure, find what is driving
database load, and check IOPS/storage headroom before or after an incident.

> Performance Insights must be enabled on the instance for the OS metric table.
> If it is disabled, the instance configuration is still printed and the OS
> table is skipped with a note.
