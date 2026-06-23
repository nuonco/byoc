# S3 Bucket

{{ $ctlApiWi := default dict .nuon.components.ctl_api_wi.outputs }} {{ if not $ctlApiWi }}

<div style="padding-bottom: 1rem;"><nuon-banner theme="warn">The <code>ctl_api_wi</code> component has not been applied yet — its outputs are required before this runbook can reach the bucket. Deploy <code>ctl_api_wi</code> first.</nuon-banner></div>

{{ end }}

### 1. `infra/byoc-s3-buckets`

First, add this install to infra/byoc-s3-buckets in mono

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

This will create the bucket we will need.

{{ else }}

_Awaiting the `ctl_api_wi` component — run it first, then this block will render with the `ctl_api_sa_unique_id` value
to add to `infra/byoc-s3-buckets`._

{{ end }}

### 2. installs/byoc/byoc-nuon

Update the inputs with the outputs for this install:

```toml
install_stack_template_bucket_region   = ""
install_stack_template_bucket          = ""
install_stack_template_bucket_role_arn = ""
```

### 3. re-deploy ctl-api

if the input update did not deploiy `ctl-api` itself.
