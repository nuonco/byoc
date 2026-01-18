{{ $region := .nuon.cloud_account.aws.region }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}
{{ $private_domain := (dig "outputs" "nuon_dns" "private_domain" "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}

<center>
  <img class="mt-0 block dark:hidden" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/light.svg"/>
  <img class="mt-0 hidden dark:block" src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg"/>
  <small>
{{ if .nuon.install_stack.outputs }}
AWS | {{ dig "account_id" "000000000000" .nuon.install_stack.outputs }} | {{ $region }} | {{ dig "vpc_id" "vpc-000000" .nuon.install_stack.outputs }}
{{ else }}
AWS | 000000000000 | xx-vvvv-00 | vpc-000000
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
  - [Configure DNS (Optional)](#configurednsoptional)
  - [Configure Github App](#configuregithubapp)
  - [Configure Google OAuth](#configure-google-oauth)
    - [Create Google OAuth Credentials](#create-google-oauth-credentials)
  - [Update Inputs](#updateinputs)
    - [Nuon configuration (Optional)](#nuonconfigurationoptional)
    - [Nuon database configuration (Optional)](#nuondatabaseconfiguration-optional)
    - [Temporal database configuration](#temporaldatabaseconfiguration)
    - [Clickhouse Cluster](#clickhousecluster)
    - [Authentication Configuration](#authenticationconfiguration)
    - [Github](#github)
    - [DNS Configuration](#dnsconfiguration)
  - [Update Secrets](#updatesecrets)
- [Application Links](#applicationlinks)
- [Accessing the EKS Cluster](#accessingtheekscluster)
- [Secrets](#secrets)
  - [Updating Secrets](#updatingsecrets)
- [Components](#components)
  - [RDS Clusters](#rdsclusters)
- [CLI](#cli)
- [State](#state)
  - [Sandbox](#sandbox)
  - [Install Stack](#installstack)
  - [Actions](#actions)
  - [Components](#components-1)
  - [Inputs](#inputs)
  - [Secrets](#secrets-1)
  - [Full State](#fullstate)

## Installing Nuon

Nuon has a few dependencies you must configure ahead of time.

- Custom DNS (Optional)
- Github App
- Google OAuth

You will need an install ID to configure these. For this reason, the first step in the installation process is to create
your Nuon install -- don't bother updating any of the inputs -- and then cancel the provision. You will use the install
ID to configure the dependencies as detailed below. Once the dependencies are ready, update your install's inputs, then
click on "Reprovision Install" in the "Manage" menu.

### Configure DNS (Optional)

To host BYOC Nuon under a custom domain, configure DNS for your `root_domain` to point to the Route53 Zone created in
the sandbox.

{{ if (and .nuon.sandbox.populated .nuon.sandbox.outputs) }}

| Attribute   | Value                                                                                          |
| ----------- | ---------------------------------------------------------------------------------------------- |
| Domain Name | {{ $public_domain }}                                                                           |
| Zone ID     | {{ dig "outputs" "nuon_dns" "public_domain" "zone_id" "Z00XXXXXXXXXXXXXXXXXX" .nuon.sandbox }} |

<!-- prettier-ignore-start -->
| Value     | Record Type | priority |
| --------- | ----------- | -------- |
{{ range $i, $ns := .nuon.sandbox.outputs.nuon_dns.public_domain.nameservers }}| {{ $ns }} | NS          | {{$i}}   |
{{ end }}
<!-- prettier-ignore-end -->

{{ else }}

> [!WARNING] Waiting on Sandbox Provision. Once the Sandbox is ready, results will be visible here.

{{ end }}

Additional Documentation

- [Creating a subdomain that uses Amazon Route 53 as the DNS service without migrating the parent domain](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingNewSubdomain.html)

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
  - Where can this GitHub app be installed?: Only on this account. (unless you have repos you need to access in other
    GitHub accounts.)

Once the app has been created, scroll to the bottom and generate a PEM key. You will need to provide this as a secret
later.

### Configure Google OAuth

Nuon uses Google OAuth for authentication. Users will sign in with their Google account.

The user key in the BYOC application is `email`. Organizations and apps are associated with the user based on this key.

#### Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **OAuth client ID**
5. Select **Web application** as the application type
6. Configure the OAuth client: | Setting | Value | | --------------------------- |
   ---------------------------------------- | | Name | BYOC Nuon (or any name) | | Authorized JavaScript origins |
   `https://auth.{{ $public_domain }}` | | Authorized redirect URIs | `https://auth.{{ $public_domain }}/auth` |

7. Note the **Client ID** and **Client Secret** - you'll need these for the install inputs and secrets

### Update Inputs

Once the dependencies have been configured, you can update your install inputs. This will trigger a workflow that's
going to fail because the install hasn't been provisioned yet. This won't cause any problems, and you can ignore it.

#### Nuon configuration (Optional)

TBD

#### Nuon database configuration (Optional)

Adjust the instance size if needed.

#### Temporal database configuration

Adjust the instance size if needed.

#### Clickhouse Cluster

Adjust the instance size if needed.

#### Authentication Configuration

| Input              | Value                                         |
| ------------------ | --------------------------------------------- |
| Auth Provider Type | `google` (default)                            |
| Auth Client ID     | Client ID from Google OAuth credentials       |
| Auth Redirect URL  | Defaults to `https://auth.{your-domain}/auth` |

#### Github

| Input                | Value                              |
| -------------------- | ---------------------------------- |
| Github App Name      | name of your github app            |
| Github App ID        | ID of your github app              |
| Github App client ID | the client ID from your Github app |

#### DNS Configuration

Your root domain is: `{{.nuon.sandbox.outputs.nuon_dns.public_dns.name}}`

### Update Secrets

When provisioning the install CloudFormation stack, you will need to provide the following secrets.

| Secret                    | Value                               |
| ------------------------- | ----------------------------------- |
| `github_app_key`          | your base64 encoded PEM key         |
| `nuon_auth_client_secret` | the client secret from Google OAuth |

The github app PEM key must be base64 encoded. AWS CloudFormation does not preserve newlines in text fields. By encoding
the PEM key before pasting it in, and decoding it later when it's read, we can preserve the newlines in the text.

The following secrets are auto-generated and do not need to be provided:

- `nuon_auth_session_key` - used for session nonce
- `nuon_auth_jwt_secret` - used to sign JWT tokens

## Application Links

Once Nuon is successfully provisioned, you can inspect it at the following URLs.

{{ if .nuon.sandbox.outputs }}

| Service                          | URL                                                                                                                                                                                                                                                                                                                            |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Dashboard                        | [app.{{ $public_domain }}](https://app.{{ $public_domain }})                                                                                                                                                                                                                                                                   |
| CTL API                          | [api.{{ $public_domain }}](https://api.{{ $public_domain }})                                                                                                                                                                                                                                                                   |
| Runner API                       | [runner.{{ $public_domain }}](https://runner.{{ $public_domain }})                                                                                                                                                                                                                                                             |
| AWS CloudFormation QuickLink URL | [{{ .nuon.install_stack.quick_link_url }}]({{ .nuon.install_stack.quick_link_url }})                                                                                                                                                                                                                                           |
| AWS CloudFormation Template URL  | [{{ .nuon.install_stack.template_url }}]({{ .nuon.install_stack.template_url }})                                                                                                                                                                                                                                               |
| Compose Preview                  | [https://{{ $region }}.console.aws.amazon.com/composer/canvas?region={{ $region }}&templateURL={{ .nuon.install_stack.template_url}}&srcConsole=cloudformation](https://{{ $region }}.console.aws.amazon.com/composer/canvas?region={{ $region }}&templateURL={{ .nuon.install_stack.template_url}}&srcConsole=cloudformation) |

{{ else }}

> Install is still provisioning...

{{ end }}

## Accessing the EKS Cluster

1. Add an access entry for the relevant role.
2. Grant the following perms: AWSEKSAdmin, AWSClusterAdmin.gtg
3. Add the cluster kubeconfig w/ the following command.

<pre>
aws --region {{ .nuon.install_stack.outputs.region }} \
    --profile your.Profile eks update-kubeconfig      \
    --name {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }} \
    --alias {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }}
</pre>

## Secrets

The following secrets are created in the CloudFormation stack and then synced into the cluster.

| Secret                   | Key(s)            | Namespace  | name                       | Source                    | Description                                 |
| ------------------------ | ----------------- | ---------- | -------------------------- | ------------------------- | ------------------------------------------- |
| clickhouse-operator-pw   | value             | clickhouse | clickhouse-operator-pw     | secrets-sync              | clickhouse operator password                |
| clickhouse-cluster-ro-pw | value             | clickhouse | clickhouse-cluster-ro-pw   | secrets-sync              | clickhouse cluster readonly user password   |
| clickhouse-cluster-pw    | value             | clickhouse | clickhouse-cluster-pw      | secrets-sync              | clickhouse cluster read/write user password |
| clickhouse-operator-pw   | username/password | clickhouse | clickhouse-operator        | action:ch_operator_creds  | creds in the format the operator wants      |
| clickhouse-cluster-pw    | value             | ctl-api    | clickhouse-cluster-pw      | action:ch_cluster_creds   | a copy of the secret in the `ctl-api` ns    |
| github-app-key           | value             | ctl-api    | github-app-key             | secrets-sync              | github app key                              |
| nuon_auth_client_secret  | value             | ctl-api    | ctl-api-auth-client-secret | secrets-sync              | OIDC client secret                          |
| nuon_auth_session_key    | value             | ctl-api    | ctl-api-auth-session-key   | secrets-sync              | Auto-generated session key                  |
| nuon_auth_jwt_secret     | value             | ctl-api    | ctl-api-auth-jwt-secret    | secrets-sync              | Auto-generated JWT signing secret           |
| rds!rds-cluster-nuon     | username/password | ctl-api    | nuon-db                    | action:nuon_rds_creds     | nuon-db credentials for ctl-api             |
| rds!rds-cluster-temporal | username/password | temporal   | temporal-db                | action:temporal_rds_creds | temporal-db credentials for temporal        |

### Updating Secrets

Secrets can be updated by re-provisioning the stack and updating the secret values.

1. Re-provision Install
2. Wait for the Install Stack to be udpated.
3. Open the CF link and copy the template url.
4. Navigate to your stack and Click "Update Stack" then click on "Create a changeset".
5. Select "Replace Existing Template" and paste the newly generated S3 URL.
6. Optionally, review with "View in Infrastructure Composer" but be sure to not make changes as these would be destroyed
   on the next provison.
7. Click Next
8. Review the changes and update the secrets as necessary. Consider adding a description.
9. Click Next
10. Click the toggles and click Next.
11. Review changes and click Submit.
12. Wait for changes to be calculated then click "Execute change set" in the top right of the window. You may need to
    click on the refresh button in the top section.
13. Accept settings, click "Execute change set."
14. Return to the "Reprovision Install" workflow window or navigate to it from the "History" tab.
15. After the sandbox reprovisions, your secrets will sync. At this point, you can accept the full reprovision or simply
    cancel the rest of the workflow.

## Components

### RDS Clusters

The nuon cluster is created w/ an admin user and a `nuon` db. This admin user is responsible for creating the `ctl_api`
user and db. This is done in an [action](/actions/).

## CLI

Install the latest version of the nuon cli ([docs](https://docs.nuon.co/cli#cli)).

```bash
brew install nuonco/tap/nuon
```

Update your `~/.nuon` config or create one specifically for this byoc install (e.g. `~/.nuon.byoc`).

Configure as follows:

```yaml
api_url: https://api.{{ $public_domain }}
```

Log in:

```yaml
nuon -f ~/.nuon.byoc login
```

## State

### Sandbox

{{ if .nuon.sandbox.outputs }}

<details>
<summary>Sandbox State</summary>
<pre class="json">{{ toPrettyJson .nuon.sandbox.outputs }}</pre>
</details>

{{ else }}

<pre>Working on it</pre>

{{ end }}

### Install Stack

<details>
  <summary>Install Stack</summary>
  <pre>{{ toPrettyJson .nuon.install_stack }}</pre>
</details>

### Actions

<details>
<summary>.nuon.actions</summary>
<pre>{{ toPrettyJson .nuon.actions }}</pre>
</details>

### Inputs

<details>
<summary>.nuon.inputs</summary>
<pre>{{ toPrettyJson .nuon.inputs }}</pre>
</details>

### Secrets

<details>
<summary>.nuon.secrets</summary>
<pre>{{ toPrettyJson .nuon.secrets }}</pre>
</details>
