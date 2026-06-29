# S3 Bucket

Enable and inspect the AWS S3 install-templates bucket for install `{{ .nuon.install.id }}`.

Nuon deploys installs into AWS using CloudFormation, and CloudFormation can only fetch its templates from S3 — so even
though this control plane runs on **GCP**, its install-templates bucket must live in **AWS**. This is what lets a GCP
control plane manage AWS BYOC installs. The three `install_stack_template_bucket*` inputs are optional and left empty at
provision time (the IAM role's trust policy federates this install's identity, so its ARN can't exist until the install
does) — the steps below fill them in.

The AWS-side resources are provisioned per-install by the
[`infra/byoc-s3-buckets`](https://github.com/nuonco/mono/tree/main/infra/byoc-s3-buckets) Terraform workspace in
`nuonco/mono` (in the `public` AWS account):

- **`{{.nuon.install.id}}-byoc-nuon-install-templates`** — the S3 bucket ctl-api uploads rendered CloudFormation
  templates to (public read only on the `templates/*` and `stacks/*` prefixes).
- **`{{.nuon.install.id}}-byoc-nuon-ctl-api-gcp`** — an AWS IAM role ctl-api assumes via **web-identity federation**:
  ctl-api mints a Google-signed OIDC token from the GKE metadata server and calls `sts:AssumeRoleWithWebIdentity`. The
  role's trust policy is scoped to `accounts.google.com:sub == <ctl-api SA unique_id>`, which is why that numeric
  `unique_id` is the key value below.

{{ $ctlApiWi := default dict .nuon.components.ctl_api_wi.outputs }} {{ if not $ctlApiWi }}

<div style="padding-bottom: 1rem;"><nuon-banner theme="warn">The <code>ctl_api_wi</code> component has not been applied yet — its outputs are required before this runbook can reach the bucket. Deploy <code>ctl_api_wi</code> first.</nuon-banner></div>

{{ end }}

### 1. `infra/byoc-s3-buckets`

First, add this install to `infra/byoc-s3-buckets` in mono.

{{ if $ctlApiWi }}

```hcl
installs = {
  ...
  # {{.nuon.install.name}}
  "{{.nuon.install.id}}" = {
    org_id               = "{{.nuon.org.id}}"
    ctl_api_sa_unique_id = "{{.nuon.components.ctl_api_wi.outputs.service_account_unique_id}}"
  }
}
```

Then `terraform apply` there — this creates the bucket and the IAM role.

{{ else }}

_Awaiting the `ctl_api_wi` component — run it first, then this block will render with the `ctl_api_sa_unique_id` value
to add to `infra/byoc-s3-buckets`._

{{ end }}

### 2. `installs/byoc/byoc-nuon`

Read this install's entry from the workspace outputs and set the three inputs from it:

| `infra/byoc-s3-buckets` output          | install input                            |
| --------------------------------------- | ---------------------------------------- |
| `install_template_buckets[<id>].id`     | `install_stack_template_bucket`          |
| `install_template_buckets[<id>].region` | `install_stack_template_bucket_region`   |
| `ctl_api_roles[<id>].arn`               | `install_stack_template_bucket_role_arn` |

```bash
terraform output -json install_template_buckets | jq -r '.["{{.nuon.install.id}}"]'
terraform output -json ctl_api_roles            | jq -r '.["{{.nuon.install.id}}"].arn'
```

```toml
install_stack_template_bucket          = "{{.nuon.install.id}}-byoc-nuon-install-templates"
install_stack_template_bucket_region   = "us-west-2"
install_stack_template_bucket_role_arn = "<ctl_api_roles[<id>].arn>"
```

These inputs are `user_configurable = false`, so set them via the install's config / API, not the install UI.

### 3. Re-deploy ctl-api

The three values feed the ctl-api configmap (`AWS_CLOUDFORMATION_STACK_TEMPLATE_BUCKET`, `..._BUCKET_REGION`,
`..._BASE_URL`, and the role ARN ctl-api assumes). Re-deploy ctl-api so it re-renders the configmap with the new inputs
— run the `deploy_control_plane` runbook, or deploy the `ctl_api` component directly, if updating the inputs did not
already redeploy it.

### 4. Verify

Run the **Inspect S3 bucket** step of this runbook. It assumes `install_stack_template_bucket_role_arn` via web identity
and reads the bucket (name, region, versioning/encryption, and up to 5 objects) — a successful read confirms the role
trust policy and the inputs are correct.

> [!NOTE] Until these inputs are set, only the AWS-CloudFormation install-management path is degraded — the rest of the
> control plane runs normally, so this can be enabled any time after provision.
