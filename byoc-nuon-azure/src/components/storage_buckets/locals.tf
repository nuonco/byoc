locals {
  install_id_sanitized = replace(lower(var.install_id), "/[^a-z0-9]/", "")
  storage_account_name = substr("nuon${local.install_id_sanitized}store", 0, 24)

  tags = {
    "NuonInstallId"     = var.install_id
    "NuonComponentName" = "storage_buckets"
  }
}
