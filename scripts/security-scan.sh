#!/usr/bin/env bash
# security-scan.sh — Static security checks for Nuon BYOC configuration files.
#
# This script covers the checks that CANNOT be expressed as Rego policies
# because they target Nuon platform configuration (TOML permission files, JSON
# boundary documents) rather than Terraform plan resources.
#
# For Terraform-level checks, see the OPA/Rego policies in:
#   byoc-nuon/policies/       (AWS)
#   byoc-nuon-gcp/policies/   (GCP)
#
# Exit codes:
#   0 — all checks passed (warnings may be present)
#   1 — one or more error-level findings detected

set -euo pipefail

ERRORS=0
WARNINGS=0

# ─── Helpers ──────────────────────────────────────────────────────────────────

warn() {
  local file="$1" line="$2" id="$3" msg="$4"
  WARNINGS=$((WARNINGS + 1))
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "::warning file=${file},line=${line}::${id}: ${msg}"
  else
    printf "\033[33mWARN\033[0m  %s:%s  %s: %s\n" "$file" "$line" "$id" "$msg"
  fi
}

error() {
  local file="$1" line="$2" id="$3" msg="$4"
  ERRORS=$((ERRORS + 1))
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "::error file=${file},line=${line}::${id}: ${msg}"
  else
    printf "\033[31mERROR\033[0m %s:%s  %s: %s\n" "$file" "$line" "$id" "$msg"
  fi
}

# ─── SEC-001: AdministratorAccess or roles/owner in lifecycle roles ───────────
#
# These are Nuon platform configs (.toml), not Terraform resources, so they
# can't be caught by plan-time Rego policies.
check_lifecycle_admin() {
  local id="SEC-001"
  local msg="Lifecycle role uses AdministratorAccess or roles/owner. Replace with least-privilege policy derived from audit logs."

  for dir in byoc-nuon/permissions byoc-nuon-gcp/permissions; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/provision.toml "$dir"/deprovision.toml "$dir"/maintenance.toml; do
      [[ -f "$f" ]] || continue
      local results
      results=$(grep -n -E '(AdministratorAccess|roles/owner)' "$f" 2>/dev/null || true)
      while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local line
        line=$(echo "$match" | cut -d: -f1)
        warn "$f" "$line" "$id" "$msg"
      done <<< "$results"
    done
  done
}

# ─── SEC-002: Boundary policy with Action:* + Resource:* ─────────────────────
#
# Permissions boundary JSON files are Nuon platform configs referenced by
# permission .toml files. A boundary that allows everything provides no
# effective guardrail.
check_wildcard_boundaries() {
  local id="SEC-002"
  local msg="Permissions boundary grants Action:* Resource:* — provides no effective constraint."

  for dir in byoc-nuon/permissions/boundaries byoc-nuon-gcp/permissions/boundaries; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*.json; do
      [[ -f "$f" ]] || continue
      local has_wildcard
      has_wildcard=$(jq -r '
        .Statement[]?
        | select(
            (.Action == "*" or .Action == ["*"]) and
            (.Resource == "*" or .Resource == ["*"])
          )
        | "found"
      ' "$f" 2>/dev/null || true)

      if [[ "$has_wildcard" == *"found"* ]]; then
        local line
        line=$(grep -n '"Action"' "$f" 2>/dev/null | head -1 | cut -d: -f1)
        line=${line:-1}
        error "$f" "$line" "$id" "$msg"
      fi
    done
  done
}

# ─── SEC-003: Service-wide wildcards in boundary/policy JSON ──────────────────
#
# The boundary and base-policy JSON files define the ceiling for what lifecycle
# roles can do. Service-wide wildcards here (iam:*, s3:*, etc.) are too broad.
check_wildcard_actions_json() {
  local id="SEC-003"
  local msg="Policy/boundary JSON contains service-wide wildcard action. Scope to specific actions."

  for dir in byoc-nuon/permissions/policies byoc-nuon/permissions/boundaries \
             byoc-nuon-gcp/permissions/policies byoc-nuon-gcp/permissions/boundaries; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/*.json; do
      [[ -f "$f" ]] || continue
      local results
      results=$(grep -n -E '"(s3|iam|kms|ecr|sts|route53|ec2|rds|ecr-public):\*"' "$f" 2>/dev/null || true)
      while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local line
        line=$(echo "$match" | cut -d: -f1)
        warn "$f" "$line" "$id" "$msg"
      done <<< "$results"
    done
  done
}

# ─── SEC-004: Missing boundary reference ─────────────────────────────────────
#
# Every lifecycle permission .toml should reference a boundary file. An empty
# permissions_boundary means the role is unconstrained.
check_missing_boundary() {
  local id="SEC-004"
  local msg="Permission role has no permissions_boundary. Add one to constrain the role's effective permissions."

  for dir in byoc-nuon/permissions byoc-nuon-gcp/permissions; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/provision.toml "$dir"/deprovision.toml "$dir"/maintenance.toml; do
      [[ -f "$f" ]] || continue
      # Check if permissions_boundary is missing or empty
      if ! grep -q 'permissions_boundary' "$f" 2>/dev/null; then
        warn "$f" "1" "$id" "$msg"
      elif grep -q 'permissions_boundary\s*=\s*""' "$f" 2>/dev/null; then
        local line
        line=$(grep -n 'permissions_boundary' "$f" | head -1 | cut -d: -f1)
        warn "$f" "$line" "$id" "$msg"
      fi
    done
  done
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  echo "============================================"
  echo "  Nuon BYOC Config Scanner"
  echo "  (Nuon platform config checks)"
  echo "============================================"
  echo ""

  check_lifecycle_admin
  check_wildcard_boundaries
  check_wildcard_actions_json
  check_missing_boundary

  echo ""
  echo "============================================"
  echo "  Results: ${ERRORS} error(s), ${WARNINGS} warning(s)"
  echo "============================================"

  if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "Config scan FAILED — ${ERRORS} error-level finding(s) must be resolved."
    exit 1
  fi

  if [[ $WARNINGS -gt 0 ]]; then
    echo ""
    echo "Config scan PASSED with ${WARNINGS} warning(s) — review before merging."
    exit 0
  fi

  echo ""
  echo "Config scan PASSED — no findings."
  exit 0
}

main "$@"
