{{- /*
ctl_api.containerResources renders the container "resources:" body
(limits/requests) by overlaying .Values.api.<name>.resources on the shared
.Values.api.resources base. Missing fields in the override silently fall
back to the base, so callers can tune only what they need.

Usage:
  resources:
    {{- include "ctl_api.containerResources" (dict "api" .Values.api "name" "public") | nindent 12 }}
*/}}
{{- define "ctl_api.containerResources" -}}
{{- $base := default (dict) .api.resources -}}
{{- $override := dig .name "resources" (dict) .api -}}
{{- $baseLimits := default (dict) $base.limits -}}
{{- $baseRequests := default (dict) $base.requests -}}
{{- $overrideLimits := default (dict) $override.limits -}}
{{- $overrideRequests := default (dict) $override.requests -}}
limits:
  cpu: {{ default $baseLimits.cpu $overrideLimits.cpu }}
  memory: {{ default $baseLimits.memory $overrideLimits.memory }}
requests:
  cpu: {{ default $baseRequests.cpu $overrideRequests.cpu }}
  memory: {{ default $baseRequests.memory $overrideRequests.memory }}
{{- end }}
