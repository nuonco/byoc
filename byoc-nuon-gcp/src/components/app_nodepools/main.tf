# Dedicated pools for the control-plane workloads, mirroring the AWS install's
# temporal and ctl-api Karpenter nodepools. Same pool.nuon.co label/taint
# convention as clickhouse_nodepools so charts pin via nodeSelector +
# tolerations.
locals {
  pool_key = "pool.nuon.co"
  pools = {
    temporal = {
      machine_type = var.temporal_machine_type
      max_nodes    = 4
    }
    ctl-api = {
      machine_type = var.ctl_api_machine_type
      max_nodes    = 18
    }
  }
}

resource "google_container_node_pool" "app" {
  for_each = local.pools

  name     = each.key
  project  = var.project_id
  location = var.cluster_location
  cluster  = var.cluster_name

  autoscaling {
    total_min_node_count = 1
    total_max_node_count = each.value.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_size_gb    = 100
    disk_type       = "pd-balanced"
    service_account = var.gke_node_pool_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      (local.pool_key) = each.key
    }

    taint {
      key    = local.pool_key
      value  = each.key
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels, node_config[0].taint]
  }
}
