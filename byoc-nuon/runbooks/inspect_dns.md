{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain := (dig "outputs" "nuon_dns" "public_domain" "name" $root_domain .nuon.sandbox) }}

<div style="padding-top:1rem;"></div>

#### Verify Delegation

The **Verify: public domain delegation** step above resolves the install's public domain from a public DNS resolver and
compares the live `NS` records to the nameservers Nuon provisioned. Read its output first:

- `RESULT: DELEGATED ✓` — the customer's registrar delegation is live; the domain resolves to the expected nameservers.
- `RESULT: NOT DELEGATED` — the domain resolves no `NS` records; the customer still needs to add the records below at
  their registrar.
- `RESULT: NOT DELEGATED (incomplete)` — some expected nameservers are missing; the registrar record set is partial or
  incorrect and must contain every expected nameserver.

#### Current DNS Configurations

When an install is created, a Route53 zone will be created for each of the domains. When these are ready, you can use
those details to configure your domain in your registrar to use the AWS nameservers.

{{ if (and .nuon.sandbox.populated .nuon.sandbox.outputs) }}

##### Root Domain

| Attribute   | Value                                                                                          |
| ----------- | ---------------------------------------------------------------------------------------------- |
| Domain Name | {{ $public_domain }}                                                                           |
| Zone ID     | {{ dig "outputs" "nuon_dns" "public_domain" "zone_id" "Z00XXXXXXXXXXXXXXXXXX" .nuon.sandbox }} |

<!-- prettier-ignore-start -->
| Value     | Record Type | priority |
| --------- | ----------- | -------- |
{{ range $i, $ns := dig "nuon_dns" "public_domain" "nameservers" (list) (default dict .nuon.sandbox.outputs) }}| {{ $ns }} | NS          | {{$i}}   |
{{ end }}
<!-- prettier-ignore-end -->

{{ else }}

> [!WARNING] Waiting on Sandbox Provision. Once the Sandbox is ready, results will be visible here.

{{ end }}

{{ $dnsZone := dig "dns_zone" dict (default dict (default dict .nuon.components.management).outputs) }}
{{ if $dnsZone }}

##### Nuon DNS Delegation Domain

| Attribute   | Value                           |
| ----------- | ------------------------------- |
| Domain Name | {{ dig "domain" "" $dnsZone }}  |
| Zone ID     | {{ dig "zone_id" "" $dnsZone }} |

<!-- prettier-ignore-start -->
| Value     | Record Type | priority |
| --------- | ----------- | -------- |
{{ range $i, $ns := dig "nameservers" (list) $dnsZone }}| {{ $ns }} | NS          | {{$i}}   |
{{ end }}
<!-- prettier-ignore-end -->

{{ else }}

<!-- prettier-ignore-start -->
> [!WARNING]
> Waiting on Sandbox Provision. Once the Sandbox is ready, results will be visible here.
<!-- prettier-ignore-end -->

{{ end }}

Additional Documentation

- [Creating a subdomain that uses Amazon Route 53 as the DNS service without migrating the parent domain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingNewSubdomain.html)
