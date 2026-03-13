# Management Component (Azure)

This Terraform module is an Azure compatibility adapter for legacy `management` outputs consumed by `ctl-api`.

It does not create cloud resources. Instead, it reshapes values already produced by the sandbox (AKS, DNS, ACR)
into the historical output contract expected by templates and services.

## Why This Exists

The original management module included cloud-provider-specific identity and DNS wiring. In this Azure app we keep
managed-identity-oriented behavior and provide compatibility outputs without reproducing provider-specific abstractions.

## Key Output Behavior

- `management_account_id` maps to the Azure subscription ID.
- `dns_zone.*` maps to Azure DNS values (`domain`, `zone_id`, `nameservers`).
- `registry.*` maps to ACR values (`id` resolves to ACR login server).
- IAM-role style outputs are intentionally set to empty strings.
- `azure_tenant_id` — Azure AD tenant ID for managed identity federation.
- `azure_subscription_id` — Azure subscription ID.
- `azure_resource_group` — Resource group for org runner resources.
- `azure_oidc_issuer_url` — OIDC issuer URL from the AKS cluster for federated credentials.
- `acr_registry_url` — ACR login server URL (convenience alias for `registry.login_server`).
