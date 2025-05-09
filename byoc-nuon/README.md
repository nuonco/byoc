<center>
  <img src="https://mintlify.s3-us-west-1.amazonaws.com/nuoninc/logo/dark.svg"/>
  <h1>BYOC Nuon</h1>
  <small>
{{ if .nuon.install_stack.outputs }}
AWS | {{ dig "account_id" "000000000000" .nuon.install_stack.outputs }} | {{ dig "region" "xx-vvvv-00" .nuon.install_stack.outputs }} | {{ dig "vpc_id" "vpc-000000" .nuon.install_stack.outputs }}
{{ else }}
AWS | 000000000000 | xx-vvvv-00 | vpc-000000
{{ end }}
  </small>
</center>

{{ if and .nuon.install_stack.populated }}

## Try it!

{{ if .nuon.install_stack.quick_link_url }}

- [AWS CloudFormation QuickLink URL]({{ .nuon.install_stack.quick_link_url }}) {{ else }}
- Generating Quick Link

{{ end }}

{{ if .nuon.install_stack.template_url }}

- [AWS CloudFormation Template URL]({{ .nuon.install_stack.template_url }})
- [Compose Preview](https://us-east-2.console.aws.amazon.com/composer/canvas?region=us-east-2&templateURL={{ .nuon.install_stack.template_url}}&srcConsole=cloudformation)
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

- [app.{{ .nuon.install.id }}](https://app.{{ .nuon.install.id }})
- **DB Host**: {{ .nuon.id }}

## Github App (wip)

1. Create an app.
2. Configure w/ details below.
3. Scroll to the bottom and generate a key.
4. Use the pem key as the value for the github action secret.
5. Out of band, ask us about a TFE secret (maybe, idk)?

| URL          |                                                     |
| ------------ | --------------------------------------------------- |
| Homepage URL | https://app.{{ .nuon.install.id }}.nuon.run         |
| Setup URL    | https://app.{{ .nuon.install.id }}.nuon.run/connect |

## Auth0 (wip)

Create an app and collect the following

| input         | example                              | actual                                              |
| ------------- | ------------------------------------ | --------------------------------------------------- |
| auth_audience | https://yourapp.us.auth0.com         | `{{ dig "auth_audience" "-" .nuon.inputs.inputs }}` |
| auth_issuer   | https://yourapp.us.auth0.com/api/v2/ | `{{ dig "auth_issuer" "-" .nuon.inputs.inputs }}`   |

To set up an auth0 app...

| URL                   |                                                               |
| --------------------- | ------------------------------------------------------------- |
| Logout URL            | https://app.{{ .nuon.install.id }}.nuon.run/api/auth/logout   |
| Allowed Web Origins   | https://app.{{ .nuon.install.id }}.nuon.run                   |
| Allowed Callback URLS | https://app.{{ .nuon.install.id }}.nuon.run/api/auth/callback |

https://app.inlkpgxanxqekogyqf2uz902ez.nuon.run/api/auth/callback

## Instructions to Access the EKS Cluster

1. Add an access entry for the relevant role.
2. Grant the following perms: AWSEKSAdmin, AWSClusterAdmin.
3. Add the cluster kubeconfig w/ the following command.

<pre>
aws --region {{ .nuon.install_stack.outputs.region }} \
    --profile your.Profile eks update-kubeconfig      \
    --name {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }} \
    --alias {{ dig "outputs" "cluster" "name" "$cluster_name" .nuon.sandbox }}
</pre>

## Sandbox

{{ if .nuon.sandbox.outputs }}

<details>
<summary>Sandbox State</summary>
<pre class="json">{{ toPrettyJson .nuon.sandbox.outputs }}</pre>
</details>

{{ else }}

<pre>Working on it</pre>

{{ end }}

## Install Stack

<details>
  <summary>Install Stack</summary>
  <pre>{{ toPrettyJson .nuon.install_stack }}</pre>
</details>

## Actions

<details id="state">
<summary>.nuon.actions</summary>
<pre>{{ toPrettyJson .nuon.actions }}</pre>
</details>

## Components

<details id="state">
<summary>.nuon.components</summary>
<pre>{{ toPrettyJson .nuon.components }}</pre>
</details>

## Full State

<details id="state">
<summary>Full Install State</summary>
<pre>{{ toPrettyJson .nuon }}</pre>
</details>

## RDS Clusters

The nuon cluster is created w/ an admin user and a `nuon` db. This admin user is responsible for creating the `ctl_api`
user and db. This is done in an [action](/actions/).
