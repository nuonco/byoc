terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    # used by install_templates_bucket.tf to wait for the bucket's public access
    # block to propagate before attaching the (public) bucket policy.
    time = {
      source = "hashicorp/time"
    }
  }
}
