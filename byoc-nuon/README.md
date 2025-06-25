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

{{ if .nuon.inputs.inputs.datadog_api_key }}

<small>[datadog](https://us5.datadoghq.com/logs?query=env%3Abyoc%20install.id%3A{{ .nuon.install.id}})</small>

{{ end }}

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
  - [Configure Auth0](#configureauth0)
    - [API](#api)
    - [Single Page Application](#singlepageapplication)
    - [Native Applicaton](#nativeapplicaton)
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
- Auth0 API

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

Create a github app so BYOC Nuon can clone code for components from private repos. (To configure a new App: https://github.com/settings/apps) Configure it thusly:

- Github app name: (pick any name)
- Homepage URL: https://app.{{ $public_domain }}
- Post Installation:
  - Setup URL: https://app.{{ $public_domain }}/connect
  - Redirect on Update: check
- Webhook:
  - Webhook: un-check
- Permissions:
  - Contents: Read-only
  - Where can this GitHub app be installed?: Only on this account. (unless you have repos you need to access in other
    GitHub accounts.)

Once the app has been created, scroll to the bottom and generate a PEM key. You will need to provide this as a secret
later.

### Configure Auth0

Nuon uses Auth0 for authentication. If you do not already have an Auth0 tenant, create one. In this tenant you must
configure:

- An action that adds `email_address` to the claim
- An API
- A Single Page Application (for the CTL API to use)
- A Native Application (for the Dashboard to use)

Nuon maintains a [terraform module](https://github.com/nuonco/byoc-auth0) to help with this process. We recommend utilizing that terraform module to configure Auth0.

#### An action that adds `email_address` to the claim
We will need to add a trigger to enrich the claim with the email. Do the following
1. Log in to your Auth0 tenant
2. Go to Actions> Library
3. Click create from scratch
4. Name the action `AddScope` and choose the latest runtime
Replace the code in the window with this:
  ```
  exports.onExecutePostLogin = async (event, api) => {
    const email = event.user.email;
    
    // Set claims 
    api.accessToken.setCustomClaim(`email`, email);
  };
  ```
5. Click Actions > triggers, click `Post-login trigger`, go to the right panel, click `Custom` then drag the `AddScope` trigger into the workflow (between the two steps), and hit save.



#### API

The value of "Identifier" must be `https://api.{{ $public_domain }}`. This will be used the audience identifier and must
match the API URL. It cannot be changed after creation, so make sure this accurate.

| Setting                                    | Value                            | Section              |
| ------------------------------------------ | -------------------------------- | -------------------- |
| Name                                       | API Gateway {{.nuon.install.id}} | In creation modal.   |
| Identifier                                 | api.{{ $public_domain }}         | In creation modal.   |
| Maximum Access Token Lifetime              | 2592000                          | Access Token Setting |
| Implicit/Hybrid Flow Access Token Lifetime | 86400                            | Access Token Setting |
| Allow Skipping User Consent                | true                             | Access Settings      |

#### Single Page Application

| Setting                          | Value                                              | Section                      |
| -------------------------------- | -------------------------------------------------- | ---------------------------- |
| Name                             | Nuon App - {{ .nuon.install.name }}                | In creation modal.           |
| Logout URL                       | <blank/>                                           | Application URIs             |
| Application Login URI            | <blank/>                                           | Application URIs             |
| Allowed Callback URLs            | https://app.{{ $public_domain }}/api/auth/callback | Application URIs             |
| Allowed Logout URLs              | https://app.{{ $public_domain }}                   | Application URIs             |
| Allowed Web Origins              | https://app.{{ $public_domain }}                   | Application URIs             |
| Alow Cross-Origin Authentication | true                                               | Cross-Origing Authentication |
| Maxmium Refresh Token Lifetime   | 31557600                                           | Refresh Token Expiration     |
| Allow Refresh Token Rotation     | true                                               | Refresh Token Rotation       |
| Rotation Overlap Period          | 0                                                  | Refresh Token Rotation       |

#### Native Applicaton

| Setting                           | Value                                        | Section                         |
| --------------------------------- | -------------------------------------------- | ------------------------------- |
| Name                              | Nuon CTL API - {{ .nuon.install.name }}      | In creation modal.              |
| Description                       | For BYOC Nuon Install {{ .nuon.install.id }} | In creation modal.              |
| Allow Cross-Origin Authentication | true                                         | Cross-Origin Authentication     |
| Device Code                       | checked                                      | Advanced Settings > Grant Types |


## (Optional) Configure additional Identity Providers
Auth0 allows multiple Identity Providers to be configured against applications. Out of the box, the above configuration 
allows for Google authentication. 

The user key in the BYOC application is `email`. Regardless of which authentication path, organizations and apps are 
associated with the user based on this key. Any new identity providers configured will need to ensure that email is returned as a claim on the access token.

We have tested Okta as an additional identity provider. The process is as follows:
[Source Documentation](https://auth0.com/docs/authenticate/identity-providers/enterprise-identity-providers/okta#add-test-user-to-okta-app-integration)

### Okta

## Step 1: Create in Okta an "OIDC Application"
- Name -  Choose any name
- Sign In Redirect = `<your auth0 tenant>/login/callback`
- Trusted Origins = `<your public domain>`
- Retain the Client ID/Secret (these will be utilized in the next step)

## Step 2: Create in Auth0 an Enterprise Connection
    1. Auth0 Dashboard > Authentication > Enterprise> Okta Workforce > Create
        - Connection name - must be unique across the tenant. We recommend setting the same name used in step 1
        - Okta domain (upper left corner of your Okta tenant)
        - Client ID + Client Secret (from step 1)
    2. Select Sync user profiles at each login
    3. User Mapping:

```
{
  "attributes": {
    "email": "${context.tokenset.email}"
  },
  "mapping_mode": "use_map"
}
```



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

| Input                          | Value                                |
| ------------------------------ | ------------------------------------ |
| Auth0 Issuer URL               | your Auth0 tenant URL                |
| Auth0 Audience                 | your Auth0 API audience              |
| Auth0 Client ID - CTL API      | your Auth0 native app client ID      |
| Auth0 Client ID - Dashboard UI | your Auth0 single-page app client ID |

#### Github

| Input                | Value                              |
| -------------------- | ---------------------------------- |
| Github App Name      | name of your github app            |
| Github App ID        | ID of your github app              |
| Github App client ID | the client ID from your Github app |

#### DNS Configuration

If you set up a custom root domain, provide it here. Otherwise, set `{{.nuon.install.id}}.nuon.run` to use a
Nuon-provided root domain.

### Update Secrets

When provisioning the install CloudFormation stack, you will need to provide 2 secrets.

| Secret             | Value                                            |
| ------------------ | ------------------------------------------------ |
| github_app_key     | your base64 encoded PEM key                      |
| auth_client_secret | the client secret from you Auth0 single-page app |

The github app PEM key must be base64 encoded. AWS CloudFormation does not preserve newlines in text fields. By encoding
the PEM key before pasting it in, and decoding it later when it's read, we can preserve the newlines in the text.

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
