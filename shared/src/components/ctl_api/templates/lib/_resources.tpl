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
{{- $limitCPU := default $baseLimits.cpu $overrideLimits.cpu -}}
{{- $limitMem := default $baseLimits.memory $overrideLimits.memory -}}
{{- $requestCPU := default $baseRequests.cpu $overrideRequests.cpu -}}
{{- $requestMem := default $baseRequests.memory $overrideRequests.memory -}}
{{- if or $limitCPU $limitMem }}
limits:
  {{- with $limitCPU }}
  cpu: {{ . }}
  {{- end }}
  {{- with $limitMem }}
  memory: {{ . }}
  {{- end }}
{{- end }}
{{- if or $requestCPU $requestMem }}
requests:
  {{- with $requestCPU }}
  cpu: {{ . }}
  {{- end }}
  {{- with $requestMem }}
  memory: {{ . }}
  {{- end }}
{{- end }}
{{- end }}
