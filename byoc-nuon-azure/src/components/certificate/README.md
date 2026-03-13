# Certificate

Compatibility component for ingress TLS on Azure.

This component no longer provisions certificates directly. It forwards the
optional Application Gateway SSL certificate name consumed by AGIC ingress
annotations.

## Inputs/Variables

| Variable                           | Description                                                                      | Example                  |
| ---------------------------------- | -------------------------------------------------------------------------------- | ------------------------ |
| `app_gateway_ssl_certificate_name` | Name of a certificate already installed on the AKS-managed Application Gateway. | `nuon-wildcard-cert`     |
| `domain_name`                      | Preserved for compatibility with previous component wiring.                      | `*.example.company.com`  |

## Example Configuration

```toml
name              = "certificate_wildcard_public"
type              = "terraform_module"
terraform_version = "1.11.3"

[public_repo]
repo      = "nuonco/byoc"
directory = "byoc-nuon-azure/src/components/certificate"
branch    = "main"

[vars]
domain_name                      = "*.{{ .nuon.sandbox.outputs.nuon_dns.public_domain.name }}"
app_gateway_ssl_certificate_name = "{{ .nuon.inputs.inputs.public_domain_certificate_name }}"
```
