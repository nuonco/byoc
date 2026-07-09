locals {
  # taint/label key mirrors the AWS install's `pool.nuon.co` convention so the
  # ClickHouse CRD podTemplates can pin onto these pools via nodeSelector +
  # tolerations. Values match the AWS nodepool names.
  pool_key         = "pool.nuon.co"
  installation_val = "clickhouse-installation"
  keeper_val       = "clickhouse-keeper"
}

# Dedicated least-privilege service account for ClickHouse nodes. Required by
# policies/gke-node-pool-service-account.rego — omitting it defaults to the
# Compute Engine SA (Editor role) and fails the policy.
# Reused from the install stack when provided — avoids runtime SA creation,
# which customer org IAM deny policies commonly forbid. The stack SA carries
# the same node role set.
locals {
  create_node_sa = var.gke_node_pool_sa_email == ""
  node_sa_email  = local.create_node_sa ? google_service_account.clickhouse_nodes[0].email : var.gke_node_pool_sa_email
}

resource "google_service_account" "clickhouse_nodes" {
  count        = local.create_node_sa ? 1 : 0
  project      = var.project_id
  account_id   = "ch-nodes-${substr(var.install_id, 0, 12)}"
  display_name = "ClickHouse GKE nodes for ${var.install_id}"
}

# Minimal roles a GKE node needs to log, export metrics, and pull images.
resource "google_project_iam_member" "clickhouse_nodes_roles" {
  for_each = local.create_node_sa ? toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]) : toset([])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.clickhouse_nodes[0].email}"
}

# clickhouse-installation (server) pool: 2 replicas with hard anti-affinity, so
# we need >=2 nodes. Regional pool, so node_locations is inherited from the
# cluster (one node per zone up to the counts below).
resource "google_container_node_pool" "clickhouse_installation" {
  name     = "clickhouse-installation"
  project  = var.project_id
  location = var.cluster_location
  cluster  = var.cluster_name

  # total counts span all zones of the regional cluster.
  autoscaling {
    total_min_node_count = 2
    total_max_node_count = 4
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.installation_machine_type
    disk_size_gb    = var.installation_disk_size_gb
    disk_type       = "pd-balanced"
    service_account = local.node_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      (local.pool_key) = local.installation_val
    }

    taint {
      key    = local.pool_key
      value  = local.installation_val
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels, node_config[0].taint]
  }
}

# clickhouse-keeper pool: exactly 3 replicas, one per zone, to keep the raft
# quorum spread across zones (matches the keeper topologySpreadConstraints).
#
# STATIC pool (node_count, no autoscaling): the keeper podTemplate uses a
# minDomains=3 / DoNotSchedule topology spread. The cluster autoscaler bootstraps
# a pool from 0 by simulating a single new node and checking the pod would then
# schedule -- but one node gives 1 domain < minDomains=3, so the predicate fails
# and the autoscaler refuses to ever add the first node (deadlock: pool stuck at
# 0, keeper pods Pending forever). A static pool sidesteps the autoscaler
# entirely and comes up with all 3 nodes at create time. node_count is per-zone
# on a regional cluster, so 1 => 3 nodes, one per zone.
resource "google_container_node_pool" "clickhouse_keeper" {
  name     = "clickhouse-keeper"
  project  = var.project_id
  location = var.cluster_location
  cluster  = var.cluster_name

  node_count = var.keeper_node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.keeper_machine_type
    disk_size_gb    = var.keeper_disk_size_gb
    disk_type       = "pd-balanced"
    service_account = local.node_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      (local.pool_key) = local.keeper_val
    }

    taint {
      key    = local.pool_key
      value  = local.keeper_val
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels, node_config[0].taint]
  }
}
