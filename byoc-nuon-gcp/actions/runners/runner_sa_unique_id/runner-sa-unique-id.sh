#!/usr/bin/env bash
#
# runner_sa_unique_id (GCP)
#
# Emits the runner's GCP service account email and numeric unique id (the OIDC
# "sub" claim). The unique id is what central byoc-secrets Terraform needs in
# its gcp_installs map to bind this install's secret-reader role trust policy
# (see mono/infra/byoc-secrets/installs.auto.tfvars).
#
# The id is read by minting an identity token from the metadata server and
# decoding its payload — the same token the install presents to AWS when it
# federates, so what we print here is exactly what STS will see as :sub.
set -euo pipefail

metadata_base="http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default"

email=$(curl -sf -H "Metadata-Flavor: Google" "$metadata_base/email")

token=$(curl -sf -H "Metadata-Flavor: Google" \
  "$metadata_base/identity?audience=sts.amazonaws.com&format=full")

# decode the JWT payload (2nd segment); re-pad base64url before decoding
payload=$(echo "$token" | cut -d. -f2 | tr '_-' '/+')
case $(( ${#payload} % 4 )) in
  2) payload="${payload}==" ;;
  3) payload="${payload}=" ;;
esac
unique_id=$(echo "$payload" | base64 -d | jq -er '.sub')

echo "runner service account email:     $email"
echo "runner service account unique id: $unique_id"

jq -cn \
  --arg email "$email" \
  --arg unique_id "$unique_id" \
  '{email: $email, unique_id: $unique_id}' \
  >> "$NUON_ACTIONS_OUTPUT_FILEPATH"
