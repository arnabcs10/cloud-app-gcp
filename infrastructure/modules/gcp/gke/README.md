# GCP GKE Module

This module creates and manages Google Kubernetes Engine (GKE) clusters with node pools and Workload Identity configuration.

## Features

- **GKE Cluster**: Regional or zonal Kubernetes cluster
- **Node Pools**: Multiple node pools with autoscaling
- **Workload Identity**: Google service account bindings for Kubernetes pods
- **Private Cluster**: Optional private cluster configuration
- **Security**: Shielded nodes, binary authorization, network policies
- **Monitoring**: Cloud Logging and Monitoring integration

## File Structure

```
gke/
├── cluster.tf                  # GKE cluster configuration
├── node_pools.tf               # Node pool configuration
├── workload_identity.tf        # Workload Identity bindings
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
└── README.md                   # This file
```

## Usage Example

```hcl
module "gke" {
  source = "./modules/gcp/gke"

  project_id    = "my-gcp-project"
  cluster_name  = "my-gke-cluster"
  region        = "us-central1"
  network       = module.network.vpc_self_link
  subnetwork    = module.network.subnet_self_links["subnet-gke"]

  pods_secondary_range_name     = "pods"
  services_secondary_range_name = "services"

  enable_private_cluster = true
  master_ipv4_cidr_block = "172.16.0.0/28"

  node_pools = [
    {
      name         = "default-pool"
      machine_type = "e2-medium"
      disk_size_gb = 100
      autoscaling = {
        min_node_count = 1
        max_node_count = 5
      }
    }
  ]

  workload_identity_service_accounts = [
    {
      name                = "my-app-sa"
      namespace           = "default"
      k8s_service_account = "my-app"
      roles               = ["roles/storage.objectViewer"]
    }
  ]
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
| cluster_name | Name of the GKE cluster | `string` | n/a | yes |
| region | The region for the cluster | `string` | n/a | yes |
| network | The VPC network | `string` | n/a | yes |
| subnetwork | The subnetwork | `string` | n/a | yes |
| node_pools | List of node pools | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | The ID of the GKE cluster |
| cluster_endpoint | The endpoint for the cluster |
| cluster_ca_certificate | The cluster CA certificate |
| workload_identity_service_accounts | Map of Workload Identity SAs |

## Notes

- Workload Identity must be enabled for secure pod-to-GCP authentication
- Use regional clusters for high availability
- Shielded nodes are enabled by default for security
- Node pools support GPU acceleration and spot instances
