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
  - [4. Delegate DNS](#4-delegate-dns)
- [Application Links](#application-links)
- [Accessing the GKE Cluster](#accessing-the-gke-cluster)
- [Secrets](#secrets)
- [Components](#components)
- [CLI](#cli)

## Installing Nuon

Installing BYOC Nuon on GCP is a simple 4 step flow:

1. Set up a GitHub App and a Google OAuth client (one-time prerequisites).
2. Sync the app into your Nuon org.
3. Create an install — fill in the inputs and provide two secrets when prompted.
4. After provisioning, add an `NS` record in your public domain to delegate to the Cloud DNS zone Nuon created.

Everything else (databases, session keys, JWT secrets, internal DNS, TLS certs) is wired up automatically.

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

### 2. Sync the App

From this repo, sync the app config into your Nuon org:

```bash
nuon apps sync
```

### 3. Create the Install

Create the install from the Nuon dashboard. You'll be asked for:

**Inputs** (filled in on the create install screen):

| Input                  | Value                                                                                                  |
| ---------------------- | ------------------------------------------------------------------------------------------------------ |
| `root_domain`          | The domain Nuon services will be served from (e.g. `byoc.yourcompany.com`).                            |
| `nuon_dns_domain`      | A separate domain used to provision DNS zones for installs (e.g. `installs.yourcompany.com`). Must not overlap with `root_domain`. |
| `github_app_name`      | Name of the GitHub App you created.                                                                    |
| `github_app_id`        | App ID from the GitHub App.                                                                            |
| `github_app_client_id` | Client ID from the GitHub App.                                                                         |
| `nuon_auth_client_id`  | Client ID from your Google OAuth client.                                                               |

**Secrets** (entered alongside the install — Nuon prompts for these):

| Secret                    | Value                                                |
| ------------------------- | ---------------------------------------------------- |
| `github_app_key`          | Base64-encoded PEM private key from your GitHub App. |
| `nuon_auth_client_secret` | Client secret from your Google OAuth client.         |

That's it. All other secrets (session keys, JWT signing key, Cloud SQL passwords, ClickHouse passwords, Temporal passwords)
are auto-generated by Nuon during provisioning — no action needed.

Provision the install. The sandbox will create the GKE cluster, networking, Cloud SQL, and the Cloud DNS zones for both
your root domain and your nuon DNS domain.

### 4. Delegate DNS

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

## Accessing the GKE Cluster

1. Ensure you have `gcloud` CLI installed and authenticated.
2. Run:

<pre>
gcloud container clusters get-credentials {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }} \
    --region {{ $region }} \
    --project {{ $project_id }}
</pre>

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
