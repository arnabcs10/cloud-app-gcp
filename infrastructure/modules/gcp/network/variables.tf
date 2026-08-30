# Network Module Variables

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "vpc_description" {
  description = "Description of the VPC network"
  type        = string
  default     = "VPC network managed by Terraform"
}

variable "routing_mode" {
  description = "Network routing mode (REGIONAL or GLOBAL)"
  type        = string
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "GLOBAL"], var.routing_mode)
    error_message = "Routing mode must be either REGIONAL or GLOBAL."
  }
}

variable "delete_default_routes" {
  description = "Whether to delete default routes on VPC creation"
  type        = bool
  default     = false
}

variable "mtu" {
  description = "Maximum Transmission Unit in bytes (1460 or 1500)"
  type        = number
  default     = 1460
  validation {
    condition     = contains([1460, 1500], var.mtu)
    error_message = "MTU must be either 1460 or 1500."
  }
}

variable "enable_private_service_connection" {
  description = "Enable private service connection for managed services like Cloud SQL"
  type        = bool
  default     = true
}

variable "private_ip_range_prefix_length" {
  description = "Prefix length for private IP range"
  type        = number
  default     = 16
}

variable "subnets" {
  description = "List of subnets to create"
  type = list(object({
    name                     = string
    ip_cidr_range            = string
    region                   = string
    description              = optional(string)
    private_ip_google_access = optional(bool)
    enable_flow_logs         = optional(bool)
    flow_logs_interval       = optional(string)
    flow_logs_sampling       = optional(number)
    flow_logs_metadata       = optional(string)
    secondary_ip_ranges = optional(list(object({
      range_name    = string
      ip_cidr_range = string
    })))
  }))
  default = []
}

variable "firewall_rules" {
  description = "List of firewall rules to create"
  type = list(object({
    name                    = string
    description             = optional(string)
    direction               = string
    priority                = optional(number)
    ranges                  = optional(list(string))
    source_tags             = optional(list(string))
    source_service_accounts = optional(list(string))
    target_tags             = optional(list(string))
    target_service_accounts = optional(list(string))
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })))
    log_config = optional(object({
      metadata = string
    }))
  }))
  default = []
}

variable "cloud_nat_config" {
  description = "Cloud NAT configuration"
  type = object({
    enabled                             = bool
    name                                = optional(string)
    router_name                         = optional(string)
    region                              = optional(string)
    nat_ip_allocate_option              = optional(string)
    source_subnetwork_ip_ranges_to_nat  = optional(string)
    min_ports_per_vm                    = optional(number)
    max_ports_per_vm                    = optional(number)
    enable_dynamic_port_allocation      = optional(bool)
    enable_endpoint_independent_mapping = optional(bool)
    log_config = optional(object({
      enable = bool
      filter = string
    }))
  })
  default = {
    enabled = false
  }
}

variable "cloud_router_asn" {
  description = "ASN for Cloud Router"
  type        = number
  default     = 64514
}
