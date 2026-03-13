# Karpenter NodePools (Azure NAP)

This helm chart manages the creation of Karpenter NodePools and their
corresponding AKSNodeClasses for Azure Node Auto Provisioning (NAP).

NodePools and AKSNodeClasses have a 1:1 correspondence. Each nodepool
gets an AKSNodeClass with the same name.

Every nodepool applies a `NoSchedule` taint `pool.nuon.co=<name>`. Only
pods with a matching toleration can schedule onto those nodes.

## Azure-specific notes

- NAP must be enabled on the AKS cluster (`enable_nap = true` in sandbox)
- AKSNodeClass uses `karpenter.azure.com/v1beta1` API
- VM selection uses `node.kubernetes.io/instance-type` for specific SKUs
  or `karpenter.azure.com/sku-family` for family-level selection (e.g., `D`)
- Zones are numbers (`"1"`, `"2"`, `"3"`) not region suffixes
