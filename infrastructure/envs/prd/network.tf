# Network Module - Production Environment

module "network" {
  source = "../../modules/gcp/network"

  project_id   = var.project_id
  vpc_name     = var.vpc_name
  routing_mode = "REGIONAL"
  mtu          = 1460

  # Enable private service connection for Cloud SQL
  enable_private_service_connection = true
  private_ip_range_prefix_length    = 16

  # Subnets
  subnets = [
    {
      name                     = "gke-subnet-${var.region}"
      ip_cidr_range            = var.gke_subnet_cidr
      region                   = var.region
      description              = "GKE cluster subnet for production"
      private_ip_google_access = true
      enable_flow_logs         = true
      flow_logs_interval       = "INTERVAL_5_SEC"
      flow_logs_sampling       = 0.5
      flow_logs_metadata       = "INCLUDE_ALL_METADATA"
      secondary_ip_ranges = [
        {
          range_name    = "gke-pods-${var.region}"
          ip_cidr_range = var.gke_pods_cidr
        },
        {
          range_name    = "gke-services-${var.region}"
          ip_cidr_range = var.gke_services_cidr
        }
      ]
    }
  ]

  # Firewall Rules
  firewall_rules = [
    # Allow internal communication within VPC
    {
      name        = "allow-internal-${var.environment}"
      description = "Allow internal communication within VPC"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = [var.gke_subnet_cidr, var.gke_pods_cidr, var.gke_services_cidr]
      allow = [
        {
          protocol = "tcp"
          ports    = ["0-65535"]
        },
        {
          protocol = "udp"
          ports    = ["0-65535"]
        },
        {
          protocol = "icmp"
        }
      ]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    # Allow SSH from authorized networks (if configured)
    {
      name        = "allow-ssh-${var.environment}"
      description = "Allow SSH from authorized networks"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = length(var.allowed_ssh_cidrs) > 0 ? var.allowed_ssh_cidrs : []
      target_tags = ["ssh-enabled"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
      log_config = {
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    # Allow health checks from GCP load balancers
    {
      name        = "allow-health-checks-${var.environment}"
      description = "Allow health checks from GCP load balancers"
      direction   = "INGRESS"
      priority    = 1000
      ranges      = ["35.191.0.0/16", "130.211.0.0/22"]
      allow = [
        {
          protocol = "tcp"
        }
      ]
    },
    # Deny all other ingress traffic (explicit deny)
    {
      name        = "deny-all-ingress-${var.environment}"
      description = "Deny all other ingress traffic"
      direction   = "INGRESS"
      priority    = 65534
      ranges      = ["0.0.0.0/0"]
      deny = [
        {
          protocol = "all"
        }
      ]
    }
  ]

  # Cloud NAT Configuration
  cloud_nat_config = {
    enabled                        = true
    name                           = "cloud-nat-${var.region}-${var.environment}"
    router_name                    = "cloud-router-${var.region}-${var.environment}"
    region                         = var.region
    nat_ip_allocate_option         = "AUTO_ONLY"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
    min_ports_per_vm               = 64
    max_ports_per_vm               = 65536
    enable_dynamic_port_allocation = true
    enable_endpoint_independent_mapping = true
    log_config = {
      enable = true
      filter = "ERRORS_ONLY"
    }
  }

  cloud_router_asn = 64514
}
