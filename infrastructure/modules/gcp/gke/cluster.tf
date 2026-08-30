# GKE Cluster Configuration

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.regional_cluster ? var.region : var.zone
  project  = var.project_id

  # VPC configuration
  network    = var.network
  subnetwork = var.subnetwork

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network policy
  network_policy {
    enabled  = var.enable_network_policy
    provider = var.enable_network_policy ? "PROVIDER_UNSPECIFIED" : null
  }

  # Cluster addons
  addons_config {
    http_load_balancing {
      disabled = !var.enable_http_load_balancing
    }
    horizontal_pod_autoscaling {
      disabled = !var.enable_horizontal_pod_autoscaling
    }
    network_policy_config {
      disabled = !var.enable_network_policy
    }
    gce_persistent_disk_csi_driver_config {
      enabled = var.enable_gce_persistent_disk_csi_driver
    }
  }

  # Private cluster configuration
  dynamic "private_cluster_config" {
    for_each = var.enable_private_cluster ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = var.enable_private_endpoint
      master_ipv4_cidr_block  = var.master_ipv4_cidr_block

      master_global_access_config {
        enabled = var.enable_master_global_access
      }
    }
  }

  # Master authorized networks
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Maintenance policy
  dynamic "maintenance_policy" {
    for_each = var.maintenance_window != null ? [1] : []
    content {
      daily_maintenance_window {
        start_time = var.maintenance_window.start_time
      }
    }
  }

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Logging and monitoring
  logging_service    = var.logging_service
  monitoring_service = var.monitoring_service

  # Resource labels
  resource_labels = var.cluster_resource_labels

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Binary authorization
  dynamic "binary_authorization" {
    for_each = var.enable_binary_authorization ? [1] : []
    content {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
    }
  }

  # Shielded nodes
  dynamic "node_config" {
    for_each = var.enable_shielded_nodes ? [1] : []
    content {
      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  }

  timeouts {
    create = var.cluster_timeout_create
    update = var.cluster_timeout_update
    delete = var.cluster_timeout_delete
  }
}
