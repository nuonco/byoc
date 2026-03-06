# Karpenter NodePool & Scheduling Reference

## NodePools

Defined in `components/values/karpenter-nodepools.yaml`, rendered by
`src/components/karpenter-nodepools/templates/nodepool.tpl`.

Every nodepool applies a `NoSchedule` taint `pool.nuon.co=<name>`. Only pods with a matching toleration can schedule
there.

The nodepool template uses per-pool `zones` when defined, otherwise defaults to `{region}a`, `{region}b`, `{region}c`.
Per-pool `disruption` config is also respected; pools without it get a default disruption policy.

| NodePool                  | Instance Types | Zones    | CPU Limit | Memory Limit | expireAfter | Disruption Policy                       |
| ------------------------- | -------------- | -------- | --------- | ------------ | ----------- | --------------------------------------- |
| `temporal`                | t3a.xlarge     | a, b, c  | 50        | 100Gi        | 168h (7d)   | WhenEmptyOrUnderutilized, 1m            |
| `clickhouse-keeper`       | t3a.medium     | a, b, c  | 14        | 32Gi         | Never       | WhenEmptyOrUnderutilized, 15m, budget=0 |
| `clickhouse-installation` | t3a.large      | a, b, c  | 14        | 1000Gi       | 2160h (90d) | WhenEmpty, 15m, budget=0                |
| `ctl-api`                 | t3a.large      | a, b, c  | 1000      | 500Gi        | 72h         | WhenEmptyOrUnderutilized, 30s           |
| `ctl-api-worker`          | t3a.xlarge     | **a, b** | 1000      | 500Gi        | 72h         | WhenEmptyOrUnderutilized, 30s           |
| `public`                  | t3a.xlarge     | a, b, c  | 500       | 1000Gi       | 732h (30d)  | WhenEmptyOrUnderutilized, 1m            |

---

## Workload → NodePool Mapping

### Pool: `public`

| Workload        | nodeSelector           | Tolerations                      | topologySpreadConstraints                                                    | PDB              |
| --------------- | ---------------------- | -------------------------------- | ---------------------------------------------------------------------------- | ---------------- |
| ctl-api-public  | `pool.nuon.co: public` | `pool.nuon.co=public:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule minDomains=2 | minAvailable 50% |
| ctl-api-admin   | `pool.nuon.co: public` | `pool.nuon.co=public:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule minDomains=2 | minAvailable 1   |
| ctl-api-auth    | `pool.nuon.co: public` | `pool.nuon.co=public:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule minDomains=2 | minAvailable 1   |
| ctl-api-runner  | `pool.nuon.co: public` | `pool.nuon.co=public:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=1 DoNotSchedule minDomains=2 | minAvailable 50% |
| ctl-api-startup | `pool.nuon.co: public` | `pool.nuon.co=public:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule minDomains=2 | —                |
| dashboard-ui    | `pool.nuon.co: public` | `pool.nuon.co=public:NoSchedule` | hostname maxSkew=1 DoNotSchedule minDomains=2; zone maxSkew=2 ScheduleAnyway | minAvailable 1   |

### Pool: `ctl-api-worker`

| Workload                                                                             | nodeSelector                   | Tolerations                              | topologySpreadConstraints                                        | PDB |
| ------------------------------------------------------------------------------------ | ------------------------------ | ---------------------------------------- | ---------------------------------------------------------------- | --- |
| ctl-api-worker-{orgs,actions,apps,components,installs,releases,general,runners} (×8) | `pool.nuon.co: ctl-api-worker` | `pool.nuon.co=ctl-api-worker:NoSchedule` | zone maxSkew=2 ScheduleAnyway; hostname maxSkew=2 ScheduleAnyway | —   |
| ctl-api-init                                                                         | `pool.nuon.co: ctl-api-worker` | `pool.nuon.co=ctl-api-worker:NoSchedule` | —                                                                | —   |

### Pool: `temporal`

| Workload            | nodeSelector             | Tolerations                        | topologySpreadConstraints                                       | PDB |
| ------------------- | ------------------------ | ---------------------------------- | --------------------------------------------------------------- | --- |
| temporal-frontend   | `pool.nuon.co: temporal` | `pool.nuon.co=temporal:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule | —   |
| temporal-worker     | `pool.nuon.co: temporal` | `pool.nuon.co=temporal:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule | —   |
| temporal-matching   | `pool.nuon.co: temporal` | `pool.nuon.co=temporal:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule | —   |
| temporal-history    | `pool.nuon.co: temporal` | `pool.nuon.co=temporal:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule | —   |
| temporal-admintools | `pool.nuon.co: temporal` | `pool.nuon.co=temporal:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule | —   |
| temporal-web        | `pool.nuon.co: temporal` | `pool.nuon.co=temporal:NoSchedule` | zone maxSkew=1 ScheduleAnyway; hostname maxSkew=2 DoNotSchedule | —   |
| temporal-init       | `pool.nuon.co: temporal` | `pool.nuon.co=temporal:NoSchedule` | —                                                               | —   |
| temporal-psql       | `pool.nuon.co: temporal` | `pool.nuon.co=temporal:NoSchedule` | —                                                               | —   |

### Pool: `clickhouse-installation`

| Workload                 | nodeSelector                            | Tolerations                                       | topologySpreadConstraints                                        | Affinity                                                              | PDB |
| ------------------------ | --------------------------------------- | ------------------------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------- | --- |
| clickhouse replicas (×2) | `pool.nuon.co: clickhouse-installation` | `pool.nuon.co=clickhouse-installation:NoSchedule` | hostname maxSkew=1 ScheduleAnyway; zone maxSkew=1 ScheduleAnyway | **podAntiAffinity required**: no two CH pods on same hostname or zone | —   |

### Pool: `clickhouse-keeper`

| Workload               | nodeSelector                      | Tolerations                                 | topologySpreadConstraints                     | PDB |
| ---------------------- | --------------------------------- | ------------------------------------------- | --------------------------------------------- | --- |
| clickhouse-keeper (×3) | `pool.nuon.co: clickhouse-keeper` | `pool.nuon.co=clickhouse-keeper:NoSchedule` | hostname maxSkew=1 DoNotSchedule minDomains=3 | —   |

---

## How Zone Redistribution Happens After Deploy

When these config changes are deployed, pods do **not** immediately move. Redistribution occurs through these
mechanisms:

| Mechanism                       | Pools affected                                                     | Timeline                                 | Manual intervention?                                                                     |
| ------------------------------- | ------------------------------------------------------------------ | ---------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Node expiry** (`expireAfter`) | temporal (7d), ctl-api-worker (72h), ctl-api (72h), public (30d)   | Within expireAfter window                | No — Karpenter drains expired nodes and replacement nodes land in underrepresented zones |
| **Disruption consolidation**    | All pools with `WhenEmptyOrUnderutilized`                          | Within consolidateAfter + budget windows | No — Karpenter may consolidate and relaunch                                              |
| **Rolling deploys**             | All helm components                                                | On next code/config deploy               | No — new pods schedule with new TSC, old pods terminate                                  |
| **Karpenter drift detection**   | `karpenter_nodepools` component has `drift_schedule = "0 0 * * *"` | Daily                                    | No — drift reconciliation replaces nodes with updated NodePool spec                      |

For the current cluster specifically:

- **ctl-api-worker** nodes expire every 72h. The two nodes currently in us-west-2a will expire and be replaced with
  zone-aware scheduling within 3 days.
- **temporal** nodes expire every 168h. The three nodes in us-west-2a will expire within 7 days and redistribute across
  zones.
- **Immediate relief** requires manual `kubectl drain` of 2-3 nodes in us-west-2a (see runbook below).

---

## Runbook: Emergency IP Recovery in a Subnet

<!-- prettier-ignore-start -->
> [!WARNING]
> please do not touch clickhouse ever. Avoid: clickhouse-keeper (PVC-bound), clickhouse-installation
> (PVC-bound + anti-affinity)
<!-- prettier-ignore-end -->

The following scripts can be run as ad-hoc actions in case a manual intervention is required. This is unlikely but can
happen if the subnet ips are needed immediately.

To immediately free IPs in an exhausted AZ subnet:

1. identify a node
2. cordon and drain it

```bash
aws ec2 describe-instances \
  --filters "Name=subnet-id,Values=<subnet-id>" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,IP:PrivateIpAddress,Pool:Tags[?Key==`karpenter.sh/nodepool`].Value|[0]}'
```

Select the node and run:

```bash
# 3. Cordon and drain one at a time
kubectl cordon <node-name> kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

These actions are also useful:

- kubectl_list_karpenter_nodes
- karpenter_rotate_nodepool
- karpenter_rotate_node

To confirm:

- aws_subnet_ids

#### All Together

We have run this to free up ips from two nodes:

```bash
# Cordon then drain one temporal node at a time — Karpenter will replace it in 2b or 2c
# thanks to the new zone spread + nodepool zone requirements
kubectl cordon i-xxxxxxxxxxxxxxxxx   # node name = ip-10-128-130-16.us-west-2.compute.internal
kubectl drain ip-10-128-130-16.us-west-2.compute.internal --ignore-daemonsets --delete-emptydir-data

# Wait for pods to reschedule, then repeat for one more:
kubectl drain ip-10-128-130-118.us-west-2.compute.internal --ignore-daemonsets --delete-emptydir-data

# Drain one of the two ctl-api-worker nodes in 2a
kubectl drain ip-10-128-130-179.us-west-2.compute.internal --ignore-daemonsets --delete-emptydir-data
```
