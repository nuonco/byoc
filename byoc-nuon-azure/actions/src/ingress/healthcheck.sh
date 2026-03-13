#!/usr/bin/env sh

set -e
set -o pipefail
set -u

echo >&2 "checking ingress..."

ingress_json=$(kubectl get --namespace "$INGRESS_NAMESPACE" ingress "$INGRESS_NAME" -o json | jq -c)
status=$(echo "$ingress_json" | jq -c '.status')
certificate_reference=$(echo "$ingress_json" | jq -r '.metadata.annotations."appgw.ingress.kubernetes.io/appgw-ssl-certificate" // ""')
hostname=$(echo "$ingress_json" | jq -r '.metadata.annotations."external-dns.alpha.kubernetes.io/hostname" // ""')
ingress_class=$(echo "$ingress_json" | jq -r '.spec.ingressClassName // .metadata.annotations."kubernetes.io/ingress.class" // ""')

# determine status
lb_ingress_count=$(echo "$status" | jq '.loadBalancer.ingress | length')
if [ "$lb_ingress_count" = "0" ];
  then
    indicator="🔴"
  else
    indicator="🟢"
fi

# compose the output
outputs=$(jq --null-input --arg cert "$certificate_reference" --arg hn "$hostname" --arg class "$ingress_class" --arg indicatorVar "$indicator" --argjson statusVar "$status" '{"status": $statusVar, "indicator": $indicatorVar, "certificate_reference": $cert, "certificate_arn": $cert, "hostname": $hn, "ingress_class": $class}')
echo "$outputs" >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
