# All dedicated app node pools, mirroring the AWS install's Karpenter
# nodepools. Workloads pin via the pool.nuon.co label/taint.
#
# node_count != null makes a pool STATIC (no autoscaling). The keeper pool
# must be static: its podTemplate uses a minDomains=3 / DoNotSchedule topology
# spread, and the cluster autoscaler bootstraps a pool from 0 by simulating a
# single node — 1 domain < minDomains fails the predicate, so the autoscaler
# never adds the first node. node_count is per-zone on a regional cluster,
# so 1 => 3 nodes, one per zone.
locals {
  pool_key = "pool.nuon.co"
  pools = {
    temporal = {
      machine_type = var.temporal_machine_type
      min_nodes    = 1
      max_nodes    = var.temporal_max_nodes
      node_count   = null
      disk_size_gb = 100
    }
    ctl-api = {
      machine_type = var.ctl_api_machine_type
      min_nodes    = 1
      max_nodes    = var.ctl_api_max_nodes
      node_count   = null
      disk_size_gb = 100
    }
    ctl-api-worker = {
      machine_type = var.ctl_api_worker_machine_type
      min_nodes    = 1
      max_nodes    = var.ctl_api_worker_max_nodes
      node_count   = null
      disk_size_gb = 100
    }
    ctl-api-workers-components = {
      machine_type = var.ctl_api_workers_components_machine_type
      min_nodes    = 1
      max_nodes    = var.ctl_api_workers_components_max_nodes
      node_count   = null
      disk_size_gb = 100
    }
    clickhouse-installation = {
      machine_type = var.ch_installation_machine_type
      min_nodes    = 2
      max_nodes    = var.ch_installation_max_nodes
      node_count   = null
      disk_size_gb = var.ch_installation_disk_size_gb
    }
    clickhouse-keeper = {
      machine_type = var.ch_keeper_machine_type
      min_nodes    = null
      max_nodes    = null
      node_count   = var.ch_keeper_node_count
      disk_size_gb = var.ch_keeper_disk_size_gb
    }
  }
}

resource "google_container_node_pool" "app" {
  for_each = local.pools

  name     = each.key
  project  = var.project_id
  location = var.cluster_location
  cluster  = var.cluster_name

  node_count = each.value.node_count

  dynamic "autoscaling" {
    for_each = each.value.node_count == null ? [1] : []
    content {
      total_min_node_count = each.value.min_nodes
      total_max_node_count = each.value.max_nodes
    }
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
    disk_size_gb    = each.value.disk_size_gb
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
