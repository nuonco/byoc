{{- if .Values.auth.enabled }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" . }}-auth
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.apiLabels" . | nindent 4 }}
    app.nuon.co/name: {{ include "common.fullname" . }}-auth
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/health-probe-path: /livez
    appgw.ingress.kubernetes.io/health-probe-interval: "5"
    appgw.ingress.kubernetes.io/health-probe-timeout: "2"
    appgw.ingress.kubernetes.io/health-probe-unhealthy-threshold: "2"
    appgw.ingress.kubernetes.io/health-probe-status-codes: "200-399"
    external-dns.alpha.kubernetes.io/hostname: {{ .Values.api.auth.domain }}
    {{- with .Values.api.auth.domain_certificate_name }}
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: {{ . | quote }}
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    {{- end }}
spec:
  ingressClassName: azure-application-gateway
  rules:
    - host: {{ .Values.api.auth.domain }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "common.fullname" . }}-auth
                port:
                  name: http
{{- end }}
