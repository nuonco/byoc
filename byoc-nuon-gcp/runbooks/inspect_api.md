{{ $inputs := (default dict (index (default dict .nuon.inputs) "inputs")) }}
{{ $root_domain := (dig "root_domain" "" $inputs) }}
{{ $public_domain  := (dig "outputs" "nuon_dns" "public_domain"  "name" $root_domain .nuon.sandbox) }}
{{ $api := dict }}{{ $apiActionID := "" }}{{ with index .nuon.actions.workflows "api_status" }}{{ with .outputs }}{{ $api = . }}{{ end }}{{ $apiActionID = dig "id" "" . }}{{ end }}
{{ $apiSteps := dig "steps" (dict) $api }}

<div style="padding-top:1rem;"></div>

<nuon-group gap="2" align="center" justify="start">{{ range $step := list "ingress-healthcheck-ctl-api-public" "ingress-healthcheck-ctl-api-admin" "ingress-healthcheck-ctl-api-runner" }}{{ $indicator := dig $step "indicator" "" $apiSteps }}{{ if eq $indicator "🟢" }}<nuon-status status="active" variant="badge"></nuon-status>{{ else if eq $indicator "🔴" }}<nuon-status status="error" variant="badge"></nuon-status>{{ else }}<nuon-status status="pending" variant="badge"></nuon-status>{{ end }}{{ end }}<nuon-label-badge label="version:{{ dig "ctl_api_version" "unknown" $api }}"></nuon-label-badge><nuon-label-badge label="git:{{ dig "ctl_api_git_ref" "unknown" $api }}"></nuon-label-badge><a href="https://api.{{ $public_domain }}/docs/index.html">Open ↗</a>{{ with dig "updated_at" "" $api }}<span style="margin-left:auto;font-size:0.85em;">Last updated by <a href="/{{ $.nuon.org.id }}/installs/{{ $.nuon.install.id }}/actions/{{ $apiActionID }}">api_status</a> <nuon-time time="{{ . }}" format="relative"></nuon-time></span>{{ end }}</nuon-group>

<div style="padding-bottom:1rem;"></div>

**Links**

| Service    | URL                                                                |
| ---------- | ------------------------------------------------------------------ |
| CTL API    | [api.{{ $public_domain }}](https://api.{{ $public_domain }})       |
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
