Deploys the Nuon control plane in four steps: syncs the `img_nuon_ctl_api` image and rolls the `ctl_api` Helm chart, then syncs `img_nuon_dashboard_ui` and rolls the `dashboard_ui` Helm chart. Use this to ship new control-plane versions without touching the rest of the install.

{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain := (dig "outputs" "nuon_dns" "public_domain" "name" $root_domain .nuon.sandbox) }}
{{ $api := dict }}{{ with index .nuon.actions.workflows "api_status" }}{{ with .outputs }}{{ $api = . }}{{ end }}{{ end }}

**Links**

| Service | URL |
|---|---|
| CTL API | [api.{{ $public_domain }}](https://api.{{ $public_domain }}) |
| Runner API | [runner.{{ $public_domain }}](https://runner.{{ $public_domain }}) |

**CLI**

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

<nuon-action-card name="api_status"></nuon-action-card>
