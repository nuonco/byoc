---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/health-probe-path: /
    appgw.ingress.kubernetes.io/health-probe-interval: "5"
    appgw.ingress.kubernetes.io/health-probe-timeout: "2"
    appgw.ingress.kubernetes.io/health-probe-unhealthy-threshold: "2"
    appgw.ingress.kubernetes.io/health-probe-status-codes: "200-399"
    external-dns.alpha.kubernetes.io/hostname: {{ .Values.ui.ingress.public_domain }}
    {{- with .Values.ui.ingress.public_domain_certificate_name }}
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: {{ . | quote }}
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    {{- end }}
spec:
  ingressClassName: azure-application-gateway
  rules:
    - host: {{ .Values.ui.ingress.public_domain }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "common.fullname" . }}
                port:
                  name: http
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
  type: ClusterIP
  ports:
    - name: http
      port: 4000
      targetPort: http
