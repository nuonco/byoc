# BYOC Nuon Read-Only Access

<!-- cf-doc md stack.yaml -->

Cross-account read-only access for BYOC Nuon installs. When `InstallReadOnlyRoleArn` is provided, creates a scoped role
assumable by that ARN with full access to the install's RDS clusters and snapshots, AWS-managed CloudWatch read-only,
and an explicit deny on SecretsManager. When `InstallReadOnlyEnableClusterAccess` is `"true"` and the EKS cluster exists,
also creates an AccessEntry granting the role ClusterAdmin and EKSAdmin on the cluster (cluster name is derived as
`n-{NuonInstallID}` per the byoc-nuon convention). Omit `InstallReadOnlyRoleArn` to disable the whole stack.

## Behavior

- The role is named `{NuonInstallID}-ReadOnlyAccess`.
- Parameter names match the ctl-api's auto-hoisted install-input parameter names exactly
  (`Install` + camelCase of the input name). With no explicit `[custom_nested_stacks.parameters]` block in the parent
  `stack.toml`, ctl-api wires these via `Ref` to the parent stack's hoisted parameters. Console edits to the parent
  params (`InstallReadOnlyRoleArn`, `InstallReadOnlyEnableClusterAccess`) propagate to the nested stack on the next
  changeset apply.
- All resources are gated on `InstallReadOnlyRoleArn` being set. Clearing it on a stack update deletes the role,
  attached policies, permission boundary, and any EKS access entry. A `WaitConditionHandle` anchors the disabled stack
  so CloudFormation accepts it with zero managed resources. The `RoleARN` output is unconditional and resolves to an
  empty string when disabled — the parent stack's PhoneHome custom resource always reads this output and would fail
  on a conditional one.
- A permission boundary caps the role to: RDS read everywhere, RDS full access on resources tagged
  `install.nuon.co/id == {NuonInstallID}`, EKS describe/list and `eks:AccessKubernetesApi` on the install's cluster,
  CloudWatch + Logs read, and an explicit `Deny secretsmanager:*`.
- `InstallReadOnlyEnableClusterAccess` can only be flipped to `"true"` after the EKS cluster exists, since the
  `AWS::EKS::AccessEntry` references it by name. Leave it `"false"` on initial creation. The cluster name is derived
  inline as `n-${NuonInstallID}` — not a parameter — because the ctl-api custom-nested-stack handler doesn't
  auto-inject `ClusterName`.
- When `InstallReadOnlyEnableClusterAccess=true`, an `EKSAccessPolicy` managed policy is created and attached to the
  role granting `eks:Describe*` and `eks:AccessKubernetesApi` on the install's cluster, plus `eks:List*` on `*`.
  This lets the assumed role run `aws eks update-kubeconfig --name n-${NuonInstallID} --region <region>` and have
  kubectl authenticate. Kubernetes-side RBAC is granted via the AccessEntry's `AmazonEKSClusterAdminPolicy` +
  `AmazonEKSAdminPolicy` associations.
- All resources are tagged with the standard Nuon trio (`install.nuon.co/id`, `org.nuon.co/id`, `app.nuon.co/id`) plus
  `role: breakglass`.

## Parameters

| Name                               | Description                                                                                      |  Type  | Default | Allowed Values |
| ---------------------------------- | ------------------------------------------------------------------------------------------------ | :----: | :-----: | :------------- |
| InstallReadOnlyRoleArn             | The customer-owned role ARN to grant cross-account access to. Leave empty to disable this stack. | String |         |                |
| InstallReadOnlyEnableClusterAccess | If `"true"`, create EKS access entries on the cluster. Only enable after the cluster exists.     | String |  false  | "", true, false |
| NuonAppID                          | The Nuon App ID. Used in tags.                                                                   | String |         |                |
| NuonInstallID                      | The Nuon Install ID; prefixed to resource names.                                                 | String |         |                |
| NuonOrgID                          | The Nuon Org ID. Used in tags.                                                                   | String |         |                |

## Outputs

| Name    | Description                                                                | Export |
| ------- | -------------------------------------------------------------------------- | ------ |
| RoleARN | The ARN of the read-only role. Empty string when the stack is disabled.    |        |
