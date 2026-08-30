# GCP Network Module

This module creates and manages GCP network resources including VPC, subnets, firewall rules, and Cloud NAT.

## Features

- **VPC Network**: Custom VPC with configurable routing mode and MTU
- **Subnets**: Multiple subnets with secondary IP ranges for GKE
- **Firewall Rules**: Flexible firewall rule configuration with allow/deny rules
- **Cloud NAT**: Managed NAT gateway for private instance internet access
- **Private Service Connection**: VPC peering for managed services (Cloud SQL, etc.)
- **VPC Flow Logs**: Optional flow logging for network monitoring

## File Structure

```
network/
├── vpc.tf                      # VPC network and private service connection
├── subnets.tf                  # Subnet configuration
├── firewall.tf                 # Firewall rules
├── cloud_nat.tf                # Cloud NAT and router
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
└── README.md                   # This file
```

## Usage Example

```hcl
module "network" {
  source = "./modules/gcp/network"

  project_id  = "my-gcp-project"
  vpc_name    = "my-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      name              = "subnet-gke"
      ip_cidr_range     = "10.0.0.0/24"
      region            = "us-central1"
      enable_flow_logs  = true
      secondary_ip_ranges = [
        {
          range_name    = "pods"
          ip_cidr_range = "10.1.0.0/16"
        },
        {
          range_name    = "services"
          ip_cidr_range = "10.2.0.0/16"
        }
      ]
    }
  ]

  firewall_rules = [
    {
      name      = "allow-ssh"
      direction = "INGRESS"
      priority  = 1000
      ranges    = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]

  cloud_nat_config = {
    enabled     = true
    region      = "us-central1"
    router_name = "my-router"
  }
}
```

## Requirements

| Name | Version |
|------|----------|
| terraform | >= 1.0 |
| google | >= 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID | `string` | n/a | yes |
| vpc_name | Name of the VPC network | `string` | n/a | yes |
| subnets | List of subnets to create | `list(object)` | `[]` | no |
| firewall_rules | List of firewall rules | `list(object)` | `[]` | no |
| cloud_nat_config | Cloud NAT configuration | `object` | `{enabled = false}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC network |
| vpc_name | The name of the VPC network |
| subnets | Map of subnet details |
| firewall_rules | Map of firewall rule details |
| cloud_nat_id | The ID of Cloud NAT |

## Notes

- Private service connection is created automatically when `enable_private_service_connection = true`
- VPC Flow Logs can be enabled per subnet
- Secondary IP ranges are required for GKE clusters
- Cloud NAT requires a Cloud Router in the same region
