package nuon

import future.keywords.if

# ── Helpers ───────────────────────────────────────────────────────────────────

mock_bucket(address, pap) := {"plan": {"resource_changes": [{
	"type": "google_storage_bucket",
	"address": address,
	"change": {
		"actions": ["create"],
		"after": {
			"uniform_bucket_level_access": true,
			"public_access_prevention": pap,
			"versioning": [{"enabled": true}],
			"force_destroy": false,
		},
	},
}]}}

# ── Deny: public access prevention not enforced ──────────────────────────────

test_deny_pap_inherited if {
	count(deny) > 0 with input as mock_bucket("google_storage_bucket.blob", "inherited")
}

test_deny_pap_unset if {
	count(deny) > 0 with input as mock_bucket("google_storage_bucket.blob", "")
}

# ── Pass: enforced ───────────────────────────────────────────────────────────

test_pass_pap_enforced if {
	count(deny) == 0 with input as mock_bucket("google_storage_bucket.blob", "enforced")
}
