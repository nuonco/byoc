{{ $region := .nuon.install_stack.outputs.region }}
{{ $project_id := .nuon.install_stack.outputs.project_id }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}
{{ $internal_domain := (dig "outputs" "nuon_dns" "internal_domain" "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}

<center>
  <img class="mt-0 block dark:hidden" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/light.svg"/>
  <img class="mt-0 hidden dark:block" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg"/>
  <small>
{{ if .nuon.install_stack.outputs }}
GCP | {{ $project_id }} | {{ $region }}
{{ else }}
GCP | project-id | region
{{ end }}
  </small>

{{ if .nuon.inputs.inputs.datadog_api_key }}<small>[DataDog](https://us5.datadoghq.com/logs?query=env%3Abyoc%20install.id%3A{{
.nuon.install.id}})</small> | {{ end }}<small>[Dashboard](https://app.{{
$public_domain }})</small> | <small>[API](https://api.{{
$public_domain }}/docs/index.html)</small>

</center>

<div>
    <table style="width:100%">
        <thead>
            <tr>
                <th></th>
                <th>Monitor</th>
                <th>Status</th>
                <th>Outputs</th>
            </tr>
        </thead>
        <tbody>
        {{ if .nuon.actions.populated }}
            {{range $name, $action := .nuon.actions.workflows}}
                {{if contains "healthcheck" $name}}
                    <tr>
                        <td style="width: 1rem">
                        {{with $action.status}}
                            {{if eq . "error"}}
                                🔴
                            {{else if eq . "finished"}}
                                🟢
                            {{else}}
                                🟡
                            {{end}}
                        {{end}}
                        </td>
                        <td>{{$name}}</td>
                        <td>{{ if or (eq $action.status "") (eq $action.status "unknown") }}pending{{ else }}{{ $action.status }}{{ end }}</td>
                        <td>{{ dig "indicator" "—" $action.outputs }}</td>
                    </tr>
                {{end}}
            {{end}}
        {{ end }}
        </tbody>
    </table>

</div>

- [Installing Nuon](#installing-nuon)
  - [1. Prerequisites](#1-prerequisites)
  - [2. Sync the App](#2-sync-the-app)
  - [3. Create the Install](#3-create-the-install)
  - [4. Run the Install Stack (provide secrets)](#4-run-the-install-stack-provide-secrets)
  - [5. Delegate DNS](#5-delegate-dns)
- [Application Links](#application-links)
- [Accessing the GKE Cluster](#accessing-the-gke-cluster)
- [Secrets](#secrets)
- [Components](#components)
- [CLI](#cli)

<a id="installing-nuon"></a>
## Installing Nuon

Installing BYOC Nuon on GCP is a simple 5-step flow:

1. Set up a GitHub App and a Google OAuth client (one-time prerequisites).
2. Sync the app into your Nuon org.
3. Create an install — via the dashboard or `nuon installs sync` with a TOML.
4. Run the generated install stack in your GCP project. Fill the two required secrets (`github_app_key`, `nuon_auth_client_secret`) into `install.tfvars` and `terraform apply`.
5. Delegate your root domain to the Cloud DNS zone Nuon provisioned.

Everything else (databases, session keys, JWT secrets, internal DNS, TLS certs) is wired up automatically.

<a id="1-prerequisites"></a>
### 1. Prerequisites

You need two things before creating the install: a **GitHub App** (so Nuon can clone component repos) and a **Google
OAuth client** (so users can sign in to the dashboard).

#### GitHub App

Create a new app at https://github.com/settings/apps with the following settings:

- **Name**: anything you like
- **Homepage URL**: `https://app.{{ $public_domain }}`
- **Setup URL** (under *Post Installation*): `https://app.{{ $public_domain }}/connect`, and check **Redirect on Update**
- **Webhook**: uncheck *Active*
- **Permissions** → *Repository permissions* → **Contents: Read-only**
- **Where can this GitHub App be installed?**: *Only on this account*

Once created:

- Note the **App ID**, **App Name**, and **Client ID** — you'll paste them into the install inputs.
- Scroll to the bottom and **generate a private key**. Base64-encode the downloaded `.pem` file — you'll provide that as
  a secret.

```bash
base64 -i your-app.private-key.pem | pbcopy
```

#### Google OAuth Client

1. Open [Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials).
2. **Create Credentials → OAuth client ID → Web application**.
3. Configure:

   | Setting                       | Value                                    |
   | ----------------------------- | ---------------------------------------- |
   | Authorized JavaScript origins | `https://auth.{{ $public_domain }}`      |
   | Authorized redirect URIs      | `https://auth.{{ $public_domain }}/auth` |

4. Note the **Client ID** (goes into inputs) and **Client Secret** (goes into secrets).

<a id="2-sync-the-app"></a>
### 2. Sync the App

From this repo, sync the app config into your Nuon org:

```bash
nuon apps sync
```

<a id="3-create-the-install"></a>
### 3. Create the Install

You can create the install two ways — pick whichever fits your workflow.

#### Option A — Dashboard

Open the Nuon dashboard, click **Create Install**, fill in the inputs (root domain, nuon DNS domain, GitHub App ID/name/client ID, Google OAuth client ID), and submit.

#### Option B — CLI with a TOML config

Create an `install.toml` with the following content, fill in the values from your prerequisites, and apply it:

```toml
# install
name             = 'my-install'
approval_option  = 'approve-all'

# input.group: inputs
[[inputs]]
# DNS — root_domain is where Nuon services are served; nuon_dns_domain is used to issue subdomains for installs and must not overlap.
root_domain       = 'byoc.yourcompany.com'
nuon_dns_domain   = 'installs.yourcompany.com'

# Auth — Google OAuth client ID (the matching client_secret is entered separately, see below).
nuon_auth_provider_type    = 'google'
nuon_auth_client_id        = '<your-google-oauth-client-id>.apps.googleusercontent.com'
nuon_auth_redirect_url     = 'https://auth.byoc.yourcompany.com/auth'
nuon_auth_allow_all_users  = 'true'
nuon_auth_allowed_domains  = 'yourcompany.com'

# GitHub App — values from the App you created.
github_app_name      = 'your-github-app-name'
github_app_id        = '123456'
github_app_client_id = 'Iv1.xxxxxxxxxxxxxxxx'
```

Apply it:

```bash
nuon installs sync --file install.toml --app-id byoc-nuon-gcp --yes
```

<a id="4-run-the-install-stack-provide-secrets"></a>
### 4. Run the Install Stack (provide secrets)

Once the install is created, Nuon's *Await Install Stack* step generates an `install.tfvars` file for you with the IDs, runner config, phone-home URL, and a `secrets = { ... }` block with the values you need to fill in. It looks like this:

```hcl
nuon_install_id        = "inl..."
nuon_org_id            = "org..."
nuon_app_id            = "app..."
runner_api_url         = "https://runner.nuon.co"
runner_api_token       = "tok..."
runner_id              = "run..."
runner_init_script_url = "https://raw.githubusercontent.com/nuonco/runner/refs/heads/main/scripts/gcp/init.sh"
phone_home_url         = "https://api.nuon.co/v1/installs/.../phone-home/..."
# ...
auto_generate_secrets = ["nuon_auth_session_key", "auth0_secret", "clickhouse_cluster_pw", ...]
secrets = {
  "nuon_auth_client_secret" = { description = "OIDC Client Secret from your identity provider.", required = false, value = "" }
  "auth0_client_secret"     = { description = "...",                                              required = false, value = "dne" }
  "github_app_key"          = { description = "Base64 encoded Github App Key",                   required = true,  value = "" }
}
```

Drop that file into the [nuonco/install-stacks](https://github.com/nuonco/install-stacks) repo under `gcp/`, then fill in the two `secrets` you provisioned in step 1:

- `github_app_key` — base64-encoded PEM private key from your GitHub App.
- `nuon_auth_client_secret` — client secret from your Google OAuth client.

Everything in `auto_generate_secrets` is generated by Nuon — leave it alone.

Then apply the install stack:

```bash
cd gcp/
cp backend.tf.example backend.tf   # optional: configure a remote backend

terraform init
terraform plan -var-file=install.tfvars
terraform apply -var-file=install.tfvars
```

You'll be prompted for `gcp_project_id` and `gcp_region`. Once `terraform apply` completes, the runner phones home and the sandbox kicks off — GKE cluster, networking, Cloud SQL, and Cloud DNS zones get provisioned.

<a id="5-delegate-dns"></a>
### 5. Delegate DNS

Once the sandbox finishes, Nuon creates a public Cloud DNS zone for your `root_domain`. To make the install reachable on
the public internet, add an `NS` record at your domain registrar pointing your `root_domain` (or the appropriate
subdomain) at the Cloud DNS nameservers shown below.

{{ if (and .nuon.sandbox.populated .nuon.sandbox.outputs) }}

| Attribute   | Value                                                                                    |
| ----------- | ---------------------------------------------------------------------------------------- |
| Domain Name | {{ $public_domain }}                                                                     |
| Zone ID     | {{ dig "outputs" "nuon_dns" "public_domain" "zone_id" "zone-xxxxxxxxxx" .nuon.sandbox }} |

<!-- prettier-ignore-start -->
| Nameserver | Record Type | priority |
| ---------- | ----------- | -------- |
{{ range $i, $ns := .nuon.sandbox.outputs.nuon_dns.public_domain.nameservers }}| {{ $ns }} | NS          | {{$i}}   |
{{ end }}
<!-- prettier-ignore-end -->

{{ else }}

> [!WARNING] Waiting on sandbox provision. Once the sandbox is ready, the nameservers to delegate to will appear here.

{{ end }}

{{ if (and .nuon.components .nuon.components.management) }}

A second zone is created for `nuon_dns_domain` — used to issue subdomains to installs managed by this BYOC Nuon. If you
plan to use that, delegate it the same way:

| Attribute   | Value                                                      |
| ----------- | ---------------------------------------------------------- |
| Domain Name | {{ .nuon.components.management.outputs.dns_zone.domain }}  |
| Zone Name   | {{ .nuon.components.management.outputs.dns_zone.name }}    |

<!-- prettier-ignore-start -->
| Nameserver | Record Type | priority |
| ---------- | ----------- | -------- |
{{ range $i, $ns := .nuon.components.management.outputs.dns_zone.nameservers }}| {{ $ns }} | NS          | {{$i}}   |
{{ end }}
<!-- prettier-ignore-end -->

{{ end }}

After the NS records propagate, the dashboard will be reachable at the URLs below.

<a id="application-links"></a>
## Application Links

{{ if .nuon.sandbox.outputs }}

| Service    | URL                                                                |
| ---------- | ------------------------------------------------------------------ |
| Dashboard  | [app.{{ $public_domain }}](https://app.{{ $public_domain }})       |
| CTL API    | [api.{{ $public_domain }}](https://api.{{ $public_domain }})       |
| Runner API | [runner.{{ $public_domain }}](https://runner.{{ $public_domain }}) |

{{ else }}

> Install is still provisioning...

{{ end }}

<a id="accessing-the-gke-cluster"></a>
## Accessing the GKE Cluster

1. Ensure you have `gcloud` CLI installed and authenticated.
2. Run:

<pre>
gcloud container clusters get-credentials {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }} \
    --region {{ $region }} \
    --project {{ $project_id }}
</pre>

<a id="secrets"></a>
## Secrets

| Secret                   | Key(s)            | Namespace  | name                       | Source                         | Description                                 |
| ------------------------ | ----------------- | ---------- | -------------------------- | ------------------------------ | ------------------------------------------- |
| clickhouse-operator-pw   | value             | clickhouse | clickhouse-operator-pw     | secrets-sync                   | clickhouse operator password                |
| clickhouse-cluster-ro-pw | value             | clickhouse | clickhouse-cluster-ro-pw   | secrets-sync                   | clickhouse cluster readonly user password   |
| clickhouse-cluster-pw    | value             | clickhouse | clickhouse-cluster-pw      | secrets-sync                   | clickhouse cluster read/write user password |
| clickhouse-operator-pw   | username/password | clickhouse | clickhouse-operator        | action:ch_operator_creds       | creds in the format the operator wants      |
| clickhouse-cluster-pw    | value             | ctl-api    | clickhouse-cluster-pw      | action:ch_cluster_creds        | a copy of the secret in the `ctl-api` ns    |
| github-app-key           | value             | ctl-api    | github-app-key             | secrets-sync                   | github app key                              |
| nuon_auth_client_secret  | value             | ctl-api    | ctl-api-auth-client-secret | secrets-sync                   | OIDC client secret                          |
| nuon_auth_session_key    | value             | ctl-api    | ctl-api-auth-session-key   | secrets-sync                   | Auto-generated session key                  |
| nuon_auth_jwt_secret     | value             | ctl-api    | ctl-api-auth-jwt-secret    | secrets-sync                   | Auto-generated JWT signing secret           |
| cloudsql_nuon            | username/password | ctl-api    | nuon-db                    | action:nuon_cloudsql_creds     | Cloud SQL credentials for ctl-api           |
| cloudsql_temporal        | username/password | temporal   | temporal-db                | action:temporal_cloudsql_creds | Cloud SQL credentials for temporal          |

<a id="components"></a>
## Components

### Cloud SQL

The nuon Cloud SQL instance is created with an admin user and a default database. The `ctl_api` user and database are
created via the `ctl_api_init_db` action (pre-deploy). Workload Identity access is granted via the `ctl_api_grant_wi`
action (pre-deploy).

### Networking

- **External Ingress**: GKE Ingress (`gce` class) with Google-managed TLS via Certificate Manager CertificateMap
- **Internal Ingress**: GKE Internal Ingress (`gce-internal` class) for admin API
- **DNS**: external-dns syncs Ingress hostnames to Cloud DNS (public and private zones)
- **Proxy-only Subnet**: Required for internal HTTP(S) load balancers

<a id="cli"></a>
## CLI

Install the latest version of the nuon cli ([docs](https://docs.nuon.co/cli#cli)):

```bash
brew install nuonco/tap/nuon
```

Configure:

```yaml
api_url: https://api.{{ $public_domain }}
```

Log in:

```bash
nuon login
```
