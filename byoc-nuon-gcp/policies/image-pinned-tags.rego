# Image Pinned Tags Policy (container_image)
#
# Every container_image component (ctl-api, dashboard-ui, temporal, clickhouse,
# ...) must reference an immutable, pinned tag. A mutable "latest" tag means a
# deploy can silently pull different bits than what was tested.
#
# Checks:
#   - deny "latest" or empty image tags   (deny)
#
# Input: container image metadata (input.image, input.tag, input.metadata).

package nuon

import future.keywords.contains
import future.keywords.if

deny contains msg if {
	input.tag == "latest"
	msg := sprintf("Image '%s' uses the mutable ':latest' tag. Pin a specific version for reproducible deploys.", [input.image])
}

deny contains msg if {
	input.tag == ""
	msg := sprintf("Image '%s' has no tag. Pin a specific version for reproducible deploys.", [input.image])
}
