{{ $region := .nuon.cloud_account.aws.region }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}
{{ $private_domain := (dig "outputs" "nuon_dns" "private_domain" "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}

<center>
  <img src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg"/>
  <h1>BYOC Nuon</h1>
  <small>
{{ if .nuon.install_stack.outputs }}
AWS | {{ dig "account_id" "000000000000" .nuon.install_stack.outputs }} | {{ $region }} | {{ dig "vpc_id" "vpc-000000" .nuon.install_stack.outputs }}
{{ else }}
AWS | 000000000000 | xx-vvvv-00 | vpc-000000
{{ end }}
  </small>
</center>

- [Installation](#installation)
- [Application Links](#application-links)
- [Configuration](#configuration)
  - [DNS (wip)](#dns-wip)
  - [Github App (wip)](#github-app-wip)
  - [Auth0 (wip)](#auth0-wip)
    - [Create the API.](#create-the-api)
    - [Create a `Single Page Application` app.](#create-a-single-page-application-app)
    - [Create a `Native Applicaton`](#create-a-native-applicaton)
  - [Configure Inputs & Secrets](#configure-inputs--secrets)
- [Accessing the EKS Cluster](#accessing-the-eks-cluster)
- [Secrets](#secrets)
  - [Updating Secrets](#updating-secrets)
- [Components](#components)
  - [RDS Clusters](#rds-clusters)
- [CLI](#cli)
- [State](#state)
  - [Sandbox](#sandbox)
  - [Install Stack](#install-stack)
  - [Actions](#actions)
  - [Components](#components-1)
  - [Inputs](#inputs)
  - [Secrets](#secrets-1)
  - [Full State](#full-state)

{{ if and .nuon.install_stack.populated }}

## Installation

{{ if .nuon.install_stack.quick_link_url }}

- [AWS CloudFormation QuickLink URL]({{ .nuon.install_stack.quick_link_url }}) {{ else }}
- Generating Quick Link

{{ end }}

{{ if .nuon.install_stack.template_url }}

- [AWS CloudFormation Template URL]({{ .nuon.install_stack.template_url }})
- [Compose
  Preview](https://{{ $region }}.console.aws.amazon.com/composer/canvas?region={{ $region }}&templateURL={{ .nuon.install_stack.template_url}}&srcConsole=cloudformation)
  {{ else }}
- Generating CloudFormation Template URL

{{ end }}

<details>
<summary>Full Template</summary>
{{ $template := .nuon.install_stack.template_json | fromJson }}
<pre>{{ $template | toPrettyJson }}</pre>
</details>
{{ else }}
No install stack configured.
{{ end }}

## Application Links

{{ if .nuon.sandbox.outputs }}

| Service    | URL                                                                |
| ---------- | ------------------------------------------------------------------ |
| Dashboard  | [app.{{ $public_domain }}](https://app.{{ $public_domain }})       |
| CTL API    | [api.{{ $public_domain }}](https://api.{{ $public_domain }})       |
| Runner API | [runner.{{ $public_domain }}](https://runner.{{ $public_domain }}) |

{{ else }}

> [!NOTE] Results will be visible after the sandbox is deployed.

{{ end }}

## Configuration

{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}
{{ $private_domain := (dig "outputs" "nuon_dns" "private_domain" "name" .nuon.inputs.inputs.root_domain .nuon.sandbox) }}

### DNS (wip)

Configure DNS for your `root_domain` to point to the Route53 Zone created in the sandbox.

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

### Github App (wip)

1. Create an app.
2. Configure w/ details below.
3. Scroll to the bottom and generate a key.
4. Use the pem key as the value for the github action secret.
5. Out of band, ask us about a TFE secret (maybe, idk)?

| URL          |                                          |
| ------------ | ---------------------------------------- |
| Homepage URL | https://app.{{ $public_domain }}         |
| Setup URL    | https://app.{{ $public_domain }}/connect |

### Auth0 (wip)

1. At a high level, deploy the install and wait for the sandbox to provision.
2. Follow these instructions.
3. Update the Auth Inputs.
4. Update the secrets (docs pending).

You will be need to create three things in Auth0:

1. An API
1. A Single Page Application
1. A Native Application

#### Create the API.

| Setting                                    | Value                            | Section              |
| ------------------------------------------ | -------------------------------- | -------------------- |
| Name                                       | API Gateway {{.nuon.install.id}} | In creation modal.   |
| Identifier                                 | api.{{ $public_domain }}         | In creation modal.   |
| Maximum Access Token Lifetime              | 2592000                          | Access Token Setting |
| Implicit/Hybrid Flow Access Token Lifetime | 86400                            | Access Token Setting |
| Allow Skipping User Consent                | true                             | Access Settings      |

#### Create a `Single Page Application` app.

Configure as follows...

| Setting                          | Value                                              | Section                      |
| -------------------------------- | -------------------------------------------------- | ---------------------------- |
| Name                             | Nuon App - {{ .nuon.install.name }}                | In creation modal.           |
| Logout URL                       | <blank/>                                           | Application URIs             |
| Application Login URL            | <blank/>                                           | Application URIs             |
| Allowed Callback URLS            | https://app.{{ $public_domain }}/api/auth/callback | Application URIs             |
| Application Logout URL           | https://app.{{ $public_domain }}                   | Application URIs             |
| Allowed Web Origins              | https://app.{{ $public_domain }}                   | Application URIs             |
| Alow Cross-Origin Authentication | true                                               | Cross-Origing Authentication |
| Maxmium Refresh Token Lifetime   | 31557600                                           | Refresh Token Expiration     |
| Allow Refresh Token Rotation     | true                                               | Refresh Token Rotation       |
| Rotation Overlap Period          | 0                                                  | Refresh Token Rotation       |

#### Create a `Native Applicaton`

Configure as follows...

| Setting                           | Value                                        | Section                     |
| --------------------------------- | -------------------------------------------- | --------------------------- |
| Name                              | Nuon CLI - {{ .nuon.install.name }}          | In creation modal.          |
| Description                       | For BYOC Nuon Install {{ .nuon.install.id }} | In creation modal.          |
| Allow Cross-Origin Authentication | true                                         | Cross-Origin Authentication |

Open the advanced settings section and enable the `device_code` grant type.

### Configure Inputs & Secrets

| App                                | Value      | Input                         |
| ---------------------------------- | ---------- | ----------------------------- |
| `API Gateway {{.nuon.install.id}}` | Identifier | `auth_audience`               |
| `app.{{ $public_domain }}`         | Domain     | `auth_issuer_url`             |
| `app.{{ $public_domain }}`         | Client ID  | `auth_client_id_dashboard_ui` |
| `Nuon CLI {{ .nuon.install.id }}`  | Client ID  | `auth_client_id_dashboard_ui` |

| App                                | Value           | Secret                | Target K8S Secret                               |
| ---------------------------------- | --------------- | --------------------- | ----------------------------------------------- |
| `API Gateway {{.nuon.install.id}}` | Client Secret   | `Auth0 Client Secret` | `dashboard-ui.dashboard-ui-auth0-client-secret` |
| -                                  | `autogenerated` | `Auth0 Secret`        | `dashboard-ui.dashboard-ui-auth0-secret`        |

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

| Secret                   | Key(s)            | Namespace    | name                     | Source                    | Description                                 |
| ------------------------ | ----------------- | ------------ | ------------------------ | ------------------------- | ------------------------------------------- |
| clickhouse-operator-pw   | value             | clickhouse   | clickhouse-operator-pw   | secrets-sync              | clickhouse operator password                |
| clickhouse-cluster-ro-pw | value             | clickhouse   | clickhouse-cluster-ro-pw | secrets-sync              | clickhouse cluster readonly user password   |
| clickhouse-cluster-pw    | value             | clickhouse   | clickhouse-cluster-pw    | secrets-sync              | clickhouse cluster read/write user password |
| clickhouse-operator-pw   | username/password | clickhouse   | clickhouse-operator      | action:ch_operator_creds  | creds in the format the operator wants      |
| clickhouse-cluster-pw    | value             | ctl-api      | clickhouse-cluster-pw    | action:ch_cluster_creds   | a copy of the secret in the `ctl-api` ns    |
| github-app-key           | value             | ctl-api      | github-app-key           | secrets-sync              | github app key                              |
| auth0_secret             | value             | dashboard-ui | auth0-secret             | secrets-sync              | Auth0 secret for the dashboard-ui           |
| auth0_client_secret      | value             | dashboard-ui | auth0-client-secret      | secrets-sync              | Auto-generated cookie secret                |
| rds!rds-cluster-nuon     | username/password | ctl-api      | nuon-db                  | action:nuon_rds_creds     | nuon-db credentials for ctl-api             |
| rds!rds-cluster-temporal | username/password | temporal     | temporal-db              | action:temporal_rds_creds | temporal-db credentials for temporal        |
| tfe-orgs-workspace-id    | value             | ctl-api      | tfe-orgs-workspace-id    | secrets-sync              | tfe org workspace id                        |
| tfe-token                | value             | ctl-api      | tfe-token                | secrets-sync              | tfe token                                   |

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

### Components

<details>
<summary>.nuon.components</summary>
<pre>{{ toPrettyJson .nuon.components }}</pre>
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

### Full State

<details>
<summary>Full Install State</summary>
<pre>{{ toPrettyJson .nuon }}</pre>
</details>
