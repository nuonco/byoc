locals {
  install_id_sanitized = regexreplace(lower(var.install_id), "[^a-z0-9]", "")
  storage_account_name = substr("nuon${local.install_id_sanitized}store", 0, 24)

  tags = {
    "NuonInstallId"     = var.install_id
    "NuonComponentName" = "s3_buckets"
  }
}
