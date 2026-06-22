{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain := (dig "outputs" "nuon_dns" "public_domain" "name" $root_domain .nuon.sandbox) }}

When an install is created, a Cloud DNS zone is provisioned for each of its
domains. Share the nameservers below with the customer so they can add `NS`
records in their registrar (or parent DNS provider) delegating the domain to
this install. Until those records are in place, services for the install will
not resolve.

{{ if (and .nuon.sandbox.populated .nuon.sandbox.outputs) }}

#### Root Domain

Services for this install are served at subdomains of this domain.

Domain:

```
{{ $public_domain }}
```

Nameservers (create an `NS` record set on the domain above with these values):

```
{{ range $ns := dig "nuon_dns" "public_domain" "nameservers" (list) (default dict .nuon.sandbox.outputs) }}{{ $ns }}
{{ end }}```

{{ else }}

> [!WARNING]
> Waiting on Sandbox Provision. Once the Sandbox is ready, the root domain records will be visible here.

{{ end }}

{{ $dnsZone := dig "dns_zone" dict (default dict (default dict .nuon.components.management).outputs) }}
{{ if $dnsZone }}

#### Nuon DNS Delegation Domain

Cloud DNS zones for managed installs are provisioned under this domain.

Domain:

```
{{ dig "domain" "" $dnsZone }}
```

Nameservers (create an `NS` record set on the domain above with these values):

```
{{ range $ns := dig "nameservers" (list) $dnsZone }}{{ $ns }}
{{ end }}```

{{ else }}

> [!WARNING]
> Waiting on the management component to deploy. Once it is ready, the delegation domain records will be visible here.

{{ end }}
