# GKE Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "region" {
  description = "The region for regional cluster"
  type        = string
}

variable "zone" {
  description = "The zone for zonal cluster"
  type        = string
  default     = null
}

variable "regional_cluster" {
  description = "Whether to create a regional cluster (true) or zonal cluster (false)"
  type        = bool
  default     = true
}

variable "network" {
  description = "The VPC network to host the cluster"
  type        = string
}

variable "subnetwork" {
  description = "The subnetwork to host the cluster"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Name of the secondary range for pods"
  type        = string
}

variable "services_secondary_range_name" {
  description = "Name of the secondary range for services"
  type        = string
}

variable "enable_network_policy" {
  description = "Enable network policy addon"
  type        = bool
  default     = true
}

variable "enable_http_load_balancing" {
  description = "Enable HTTP load balancing addon"
  type        = bool
  default     = true
}

variable "enable_horizontal_pod_autoscaling" {
  description = "Enable horizontal pod autoscaling addon"
  type        = bool
  default     = true
}

variable "enable_gce_persistent_disk_csi_driver" {
  description = "Enable GCE persistent disk CSI driver"
  type        = bool
  default     = true
}

variable "enable_private_cluster" {
  description = "Enable private cluster configuration"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for the cluster master"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation for the master network"
  type        = string
  default     = "172.16.0.0/28"
}

variable "enable_master_global_access" {
  description = "Enable global access to the master endpoint"
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "List of master authorized networks"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    start_time = string
  })
  default = null
}

variable "release_channel" {
  description = "Release channel for GKE cluster (RAPID, REGULAR, STABLE, UNSPECIFIED)"
  type        = string
  default     = "REGULAR"
  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "UNSPECIFIED"], var.release_channel)
    error_message = "Release channel must be one of: RAPID, REGULAR, STABLE, UNSPECIFIED."
  }
}

variable "logging_service" {
  description = "The logging service to use"
  type        = string
  default     = "logging.googleapis.com/kubernetes"
}

variable "monitoring_service" {
  description = "The monitoring service to use"
  type        = string
  default     = "monitoring.googleapis.com/kubernetes"
}

variable "cluster_resource_labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Enable deletion protection for the cluster"
  type        = bool
  default     = true
}

variable "enable_binary_authorization" {
  description = "Enable binary authorization for the cluster"
  type        = bool
  default     = false
}

variable "enable_shielded_nodes" {
  description = "Enable shielded nodes for the cluster"
  type        = bool
  default     = true
}

variable "cluster_timeout_create" {
  description = "Timeout for cluster creation"
  type        = string
  default     = "45m"
}

variable "cluster_timeout_update" {
  description = "Timeout for cluster updates"
  type        = string
  default     = "45m"
}

variable "cluster_timeout_delete" {
  description = "Timeout for cluster deletion"
  type        = string
  default     = "45m"
}

variable "node_pools" {
  description = "List of node pools"
  type = list(object({
    name               = string
    initial_node_count = optional(number)
    machine_type       = optional(string)
    disk_size_gb       = optional(number)
    disk_type          = optional(string)
    image_type         = optional(string)
    preemptible        = optional(bool)
    spot               = optional(bool)
    service_account    = optional(string)
    oauth_scopes       = optional(list(string))
    labels             = optional(map(string))
    metadata           = optional(map(string))
    tags               = optional(list(string))
    auto_repair        = optional(bool)
    auto_upgrade       = optional(bool)
    enable_gcfs        = optional(bool)
    autoscaling = optional(object({
      min_node_count       = number
      max_node_count       = number
      location_policy      = optional(string)
      total_min_node_count = optional(number)
      total_max_node_count = optional(number)
    }))
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })))
    accelerator = optional(object({
      type               = string
      count              = number
      gpu_partition_size = optional(string)
      gpu_sharing_config = optional(object({
        gpu_sharing_strategy       = string
        max_shared_clients_per_gpu = number
      }))
    }))
    upgrade_settings = optional(object({
      max_surge       = optional(number)
      max_unavailable = optional(number)
      strategy        = optional(string)
      blue_green_settings = optional(object({
        node_pool_soak_duration = optional(string)
        batch_percentage        = optional(number)
        batch_node_count        = optional(number)
        batch_soak_duration     = optional(string)
      }))
    }))
  }))
  default = []
}

variable "node_pool_timeout_create" {
  description = "Timeout for node pool creation"
  type        = string
  default     = "30m"
}

variable "node_pool_timeout_update" {
  description = "Timeout for node pool updates"
  type        = string
  default     = "30m"
}

variable "node_pool_timeout_delete" {
  description = "Timeout for node pool deletion"
  type        = string
  default     = "30m"
}

variable "workload_identity_service_accounts" {
  description = "List of Workload Identity service account bindings"
  type = list(object({
    name                 = string
    namespace            = string
    k8s_service_account  = string
    roles                = list(string)
    description          = optional(string)
  }))
  default = []
}
