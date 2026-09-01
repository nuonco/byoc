# gcp-bucket

AWS-side resources for a Nuon BYOC control plane running on **GCP**.

Nuon deploys installs into AWS using CloudFormation, and CloudFormation can only
fetch its templates from S3. So even when the control plane runs on GCP, the
install templates bucket must live in AWS. This module creates:

- **`install_template_bucket`** — the S3 bucket ctl-api uploads rendered
  CloudFormation templates to. Public read is allowed only on the `templates/*`
  and `stacks/*` prefixes so CloudFormation in the target AWS account(s) can
  fetch them by URL.
- **`ctl_api` IAM role** — a role the GCP `ctl-api` service account assumes via
  web-identity federation to write to the bucket.

## How ctl-api reaches the bucket from GCP

ctl-api has no AWS credentials on GCP. Instead:

1. Its GCP service account (bound to the pod via Workload Identity) mints a
   Google-signed OIDC token from the metadata server with
   `audience=sts.amazonaws.com`.
2. ctl-api calls `sts:AssumeRoleWithWebIdentity` against the `ctl_api` role.
3. The returned temporary AWS credentials are used with the S3 SDK to upload
   templates.

`accounts.google.com` is a built-in AWS web-identity provider, so no
`aws_iam_openid_connect_provider` resource is required. The trust policy is
scoped to `accounts.google.com:sub == var.ctl_api_sa_unique_id` (the numeric
`unique_id` of the ctl-api GSA) **and nothing else** — in particular, not to
`aud`. Google service-account identity tokens always carry an `azp` claim set
to the SA's numeric id, and AWS substitutes `azp` for the
`accounts.google.com:aud` condition key whenever it is present, so an `aud`
condition could never match the requested audience. `sub` uniquely pins the
service account, which is the binding that matters.

This is the GCP analog of the EKS IRSA pattern used in
`byoc-nuon/src/components/s3_buckets` (`clickhouse_role`), which federates the
cluster OIDC provider instead of Google.

The code path on the ctl-api side already exists:
`nuon/pkg/aws/assume-role` (`UseGCPOIDC`) and `nuon/pkg/aws/credentials`.

## Inputs

| Name | Description |
| ---- | ----------- |
| `install_id` | Nuon install ID. |
| `region` | AWS region for the install templates bucket. |
| `ctl_api_sa_unique_id` | `google_service_account.ctl_api.unique_id` from the GCP side. |

## Outputs

| Name | Maps to ctl-api config |
| ---- | ---------------------- |
| `install_template_bucket.id` | `AWS_CLOUDFORMATION_STACK_TEMPLATE_BUCKET` |
| `install_template_bucket.region` | `AWS_CLOUDFORMATION_STACK_TEMPLATE_BUCKET_REGION` |
| `install_template_bucket.base_url` | `AWS_CLOUDFORMATION_STACK_TEMPLATE_BASE_URL` |
| `ctl_api_role.arn` | role ARN ctl-api assumes with `UseGCPOIDC` (new config field) |
