<div style="padding-top:1rem;"></div>

<nuon-banner theme="warn">Mutating, on a live database. Step 1 grows the data
PVCs in place (additive — no restart, no data rewrite). Step 3 redeploys
<code>clickhouse_cluster</code>, which makes the operator recreate the
StatefulSet and <strong>may briefly restart the ClickHouse pods</strong>. Data is
preserved throughout (PVCs are <code>Retain</code> and Kubernetes cannot shrink a
PVC). Read this first.</nuon-banner>

<div style="padding-top:1rem;"></div>

## What this runbook does

Grows the ClickHouse **data** PVCs online, then reconciles source so it sticks.
Three steps, run in this order — the order is enforced by the runbook, and it
matters (see step 3):

1. **`ch_pvc_expand`** (action) — grows the live PVCs.
   - **Preflights** — prints PVC size/capacity + the SC `allowVolumeExpansion`
     flag; **aborts if no `csi-resizer` is present** (a resize without one hangs
     indefinitely); and **aborts if any CH StatefulSet has
     `persistentVolumeClaimRetentionPolicy.whenDeleted: Delete`** — because step 3
     recreates the STS, and `Delete` would drop the data PVC (unset defaults to
     `Retain`, which is safe).
   - **Enables expansion** — patches `allowVolumeExpansion: true` on `ebi`
     (mutable false→true, non-destructive).
   - **Grows the PVCs** — patches each data PVC (by `DATA_PVC_PREFIX`) to
     `TARGET_SIZE`; **never shrinks** (skips any PVC already ≥ target).
   - **Waits & verifies** — polls until `.status.capacity` reaches the target
     (EBS volume then ext4 filesystem grow, both online), prints final state.
2. **`storage_classes: Deploy`** — persists `allowVolumeExpansion: true` in
   source (no-op against the live SC that step 1 already patched).
3. **`clickhouse_cluster: Deploy`** — persists the larger `volumeClaimTemplates`
   size in the CHI. Because a StatefulSet's `volumeClaimTemplates` is
   **immutable**, the operator **recreates the STS** to apply the new size:
   it deletes the STS orphan-style (pods keep running / are re-adopted) and the
   PVCs — already at the target from step 1 and marked `Retain` — are re-adopted
   by name with **no resize and no data copy**. This step **may briefly restart
   the CH pods**; 2 replicas + ctl-api retries make it a blip, not an outage.

**Why step 1 must run before step 3:** with the PVCs already at target, the
recreated STS adopts volumes that already match — nothing to reconcile. If you
deployed first (PVCs still small), the operator would have to recreate the STS
*and* drive the resize at once — more churn, more room to get stuck. The runbook
enforces this order, so just run it top to bottom.

## What happens to the StatefulSet

**After step 1 (the expand action) alone: the STS is NOT recreated, and nothing
restarts.** The action patches the **PVC objects** directly — it never touches
the StatefulSet. The PVC is a separate object from the STS. So after it runs:

- **PVCs:** at the target size, live, grown online by the CSI resizer.
- **Running pods:** keep using those same grown PVCs — no restart.
- **STS `volumeClaimTemplates`:** still shows the old size — stale, but harmless.
  That template is only ever read when the STS needs to create a **new** PVC (a
  new replica ordinal, or a pod whose PVC was deleted). Existing PVCs are already
  bound and grown, so the cluster runs fine with a stale template.

So a low-disk **incident is fully resolved after step 1**. The STS recreation
only enters the picture at the source-reconcile step.

**When the STS gets recreated — step 3, the `clickhouse_cluster` redeploy.** A
StatefulSet's `volumeClaimTemplates` is **immutable** — you cannot edit the size
in place. So when `clickhouse_cluster` is deployed with the CHI now requesting the
larger size, the Altinity operator sees: desired vct = new size, live STS vct =
old size, can't patch it → **it deletes and recreates the STS.**

That recreation is safe here **only because the PVCs survive it**: the STS
`persistentVolumeClaimRetentionPolicy` is `Retain` (the preflight aborts if it's
`Delete`), so the PVCs are not garbage-collected when the STS is deleted; the
recreated STS re-adopts them by name; and Kubernetes cannot shrink a PVC, so the
grown volumes can't be reverted. The only visible effect is a possible brief pod
restart.

## After running — confirm healthy

- StatefulSets show the new `volumeClaimTemplates` size.
- All data PVCs are `Bound` at the target.
- All ClickHouse pods are `Ready`.

## Why online expansion works here

The data PVCs bind to the `ebi` StorageClass (in-tree `kubernetes.io/aws-ebs`
provisioner, CSI-migrated to `ebs.csi.aws.com` on EKS ≥ 1.23). The EBS CSI
controller runs with the `csi-resizer` sidecar, so a change to the PVC's
requested size is applied to the live volume without detaching or restarting the
pod. The preflight confirms the resizer is present before touching anything.

## Parameters (`ch_pvc_expand` step env)

| Var | Default | Notes |
|---|---|---|
| `TARGET_SIZE` | `100Gi` | Target size. **Never shrinks.** EBS enforces a ~6h cooldown between resizes of the same volume, so size generously and resize once. |
| `STORAGE_CLASS` | `ebi` | StorageClass to enable expansion on. |
| `DATA_PVC_PREFIX` | `data-volume-template-` | Prefix identifying the data PVCs. |
| `NAMESPACE` | `clickhouse` | |

## When to use

The ClickHouse data disk is running low (e.g. an `inspect_clickhouse` snapshot or
a disk alert shows the data PVC filling). Table data lives in
`/var/lib/clickhouse/store`; this grows the volume it sits on.

## If a resize stalls

`.status.capacity` may briefly lag behind `.spec…requests` with a
`FileSystemResizePending` condition, then catch up within a minute or two. If it
is still stuck after the wait loop, inspect the PVC and the resizer:

```
kubectl describe pvc <name> -n clickhouse
kubectl logs -n <ebs-csi ns> deploy/ebs-csi-controller -c csi-resizer
```
