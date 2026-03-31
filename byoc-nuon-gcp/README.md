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
                        <td>{{$action.status}}</td>
                        <td><pre style="margin-top: 0; margin-bottom: 0">{{$action.outputs}}</pre></td>
                    </tr>
                {{end}}
            {{end}}
        {{ end }}
        </tbody>
    </table>

</div>

- [Installing Nuon](#installingnuon)
  - [Configure DNS](#configuredns)
  - [Configure Github App](#configuregithubapp)
  - [Configure Google OAuth](#configure-google-oauth)
  - [Update Inputs](#updateinputs)
  - [Update Secrets](#updatesecrets)
- [Application Links](#applicationlinks)
- [Accessing the GKE Cluster](#accessingthegkecluster)
- [Secrets](#secrets)
- [Components](#components)
- [CLI](#cli)

## Installing Nuon

Nuon has a few dependencies you must configure ahead of time.

- Custom DNS (Optional)
- Github App
- Google OAuth

You will need an install ID to configure these. For this reason, the first step in the installation process is to create
your Nuon install -- don't bother updating any of the inputs -- and then cancel the provision. You will use the install
ID to configure the dependencies as detailed below. Once the dependencies are ready, update your install's inputs, then
click on "Reprovision Install" in the "Manage" menu.

### Configure DNS

There are two domains at play with a BYOC Nuon deployment. The first is the `root_domain` under which all of the
services (e.g. APIs & Frontend) are served. The second, `nuon_dns_domain`, is a domain which you can use to
automate the provisioning of Cloud DNS zones for installs.

|                 | Input             | Description                                                                          |
| --------------- | ----------------- | ------------------------------------------------------------------------------------ |
| Root Domain     | `root_domain`     | The root domain from which the nuon services are served.                             |
| Nuon DNS Domain | `nuon_dns_domain` | The domain used to provision domains for installs managed by this BYOC Nuon Install. |

BYOC Nuon should be hosted under a custom domain of your choice, for example:

- `byoc.organization.com`

Nuon DNS should be hosted under a separate domain or a dedicated subdomain, such as:

- `installs.organization.com`
- `hosted.organization.io`

<!-- prettier-ignore-start -->
> [!NOTE]
> We strongly suggest you choose your domains so there is NO overlap between the two.
<!-- prettier-ignore-end -->

#### Current DNS Configurations

When an install is created, Cloud DNS zones will be created for each of the domains. When these are ready, you can
configure your domain registrar to use the GCP nameservers.

{{ if (and .nuon.sandbox.populated .nuon.sandbox.outputs) }}

##### Root Domain

| Attribute   | Value                                                                                    |
| ----------- | ---------------------------------------------------------------------------------------- |
| Domain Name | {{ $public_domain }}                                                                     |
| Zone ID     | {{ dig "outputs" "nuon_dns" "public_domain" "zone_id" "zone-xxxxxxxxxx" .nuon.sandbox }} |

<!-- prettier-ignore-start -->
| Value     | Record Type | priority |
| --------- | ----------- | -------- |
{{ range $i, $ns := .nuon.sandbox.outputs.nuon_dns.public_domain.nameservers }}| {{ $ns }} | NS          | {{$i}}   |
{{ end }}
<!-- prettier-ignore-end -->

{{ else }}

> [!WARNING] Waiting on Sandbox Provision. Once the Sandbox is ready, results will be visible here.

{{ end }}

{{ if (and .nuon.components .nuon.components.management) }}

##### Nuon DNS Root Domain

| Attribute   | Value                                                      |
| ----------- | ---------------------------------------------------------- |
| Domain Name | {{ .nuon.components.management.outputs.dns_zone.domain }}  |
| Zone Name   | {{ .nuon.components.management.outputs.dns_zone.name }}    |

<!-- prettier-ignore-start -->
| Value     | Record Type | priority |
| --------- | ----------- | -------- |
{{ range $i, $ns := .nuon.components.management.outputs.dns_zone.nameservers }}| {{ $ns }} | NS          | {{$i}}   |
{{ end }}
<!-- prettier-ignore-end -->

{{ else }}

> [!WARNING] Waiting on Management Component. Once deployed, results will be visible here.

{{ end }}

### Configure Github App

Create a github app so BYOC Nuon can clone code for components from private repos. (To configure a new App:
https://github.com/settings/apps) Configure it thusly:

- Github app name: (pick any name)
- Homepage URL: [https://app.{{ $public_domain }}](https://app.{{ $public_domain }})
- Post Installation:
  - Setup URL: [https://app.{{ $public_domain }}/connect](https://app.{{ $public_domain }}/connect)
  - Redirect on Update: check
- Webhook:
  - Webhook: un-check
- Permissions:
  - Contents: Read-only
  - Where can this GitHub app be installed?: Only on this account.

Once the app has been created, scroll to the bottom and generate a PEM key. You will need to provide this as a secret
later.

### Configure Google OAuth

Nuon uses Google OAuth for authentication. Users will sign in with their Google account.

#### Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **OAuth client ID**
5. Select **Web application** as the application type
6. Configure the OAuth client (see table below)
7. Note the **Client ID** and **Client Secret** - you'll need these for the install inputs and secrets

| Setting                       | Value                                    |
| ----------------------------- | ---------------------------------------- |
| Name                          | `BYOC Nuon` (or any name)                |
| Authorized JavaScript origins | `https://auth.{{ $public_domain }}`      |
| Authorized redirect URIs      | `https://auth.{{ $public_domain }}/auth` |

### Update Inputs

Once the dependencies have been configured, you can update your install inputs.

#### Authentication Configuration

| Input              | Value                              |
| ------------------ | ---------------------------------- |
| Auth Provider Type | `google` (default)                 |
| Auth Client ID     | Client ID from Google OAuth        |

#### Github

| Input                | Value                              |
| -------------------- | ---------------------------------- |
| Github App Name      | name of your github app            |
| Github App ID        | ID of your github app              |
| Github App client ID | the client ID from your Github app |

#### DNS Configuration

|                 | Input                                                           | Description                                                                          |
| --------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Root Domain     | `{{.nuon.sandbox.outputs.nuon_dns.public_domain.name}}`         | The root domain from which the nuon services are served.                             |
| Nuon DNS Domain | `{{.nuon.components.management.outputs.dns_zone.domain}}`       | The domain used to provision domains for installs managed by this BYOC Nuon Install. |

### Update Secrets

| Secret                    | Value                               |
| ------------------------- | ----------------------------------- |
| `github_app_key`          | your base64 encoded PEM key         |
| `nuon_auth_client_secret` | the client secret from Google OAuth |

The following secrets are auto-generated and do not need to be provided:

- `nuon_auth_session_key` - used for session nonce
- `nuon_auth_jwt_secret` - used to sign JWT tokens

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
2. Run the following command to get cluster credentials:

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

Install the latest version of the nuon cli ([docs](https://docs.nuon.co/cli#cli)).

```bash
brew install nuonco/tap/nuon
```

Configure as follows:

```yaml
api_url: https://api.{{ $public_domain }}
```

Log in:

```bash
nuon login
```
