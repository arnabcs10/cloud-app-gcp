# GCP IAM Module

This module creates and manages GCP service accounts and IAM bindings for project-level and service account-level permissions.

## Features

- **Service Accounts**: Create multiple service accounts with descriptions
- **Service Account Keys**: Optional key generation for service accounts
- **Project IAM Bindings**: Assign roles to service accounts at project level
- **Service Account IAM**: Manage impersonation and delegation permissions
- **Custom Bindings**: Flexible IAM bindings with conditional access
- **GKE Integration**: Pre-configured service account for GKE nodes

## File Structure

```
iam/
├── service_accounts.tf         # Service account creation and keys
├── iam_bindings.tf             # IAM role bindings
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
└── README.md                   # This file
```

## Usage Example

### Basic Service Accounts

```hcl
module "iam" {
  source = "./modules/gcp/iam"

  project_id = "my-gcp-project"

  service_accounts = [
    {
      account_id   = "my-app-sa"
      display_name = "My Application Service Account"
      description  = "Service account for my application"
      project_roles = [
        "roles/storage.objectViewer",
        "roles/pubsub.publisher"
      ]
    },
    {
      account_id   = "gke-node-sa"
      display_name = "GKE Node Service Account"
      project_roles = [
        "roles/logging.logWriter",
        "roles/monitoring.metricWriter"
      ]
    }
  ]
}
```

### GKE Node Service Account

```hcl
module "iam" {
  source = "./modules/gcp/iam"

  project_id = "my-gcp-project"

  service_accounts = [
    {
      account_id   = "gke-node-sa"
      display_name = "GKE Node Pool Service Account"
    }
  ]

  create_gke_node_service_account = true
  gke_node_service_account_key    = "gke-node-sa"
}
```

### Service Account with Impersonation

```hcl
service_accounts = [
  {
    account_id   = "ci-cd-sa"
    display_name = "CI/CD Pipeline Service Account"
    iam_bindings = [
      {
        role   = "roles/iam.serviceAccountUser"
        member = "user:admin@example.com"
      }
    ]
  }
]
```

### Custom IAM Bindings with Conditions

```hcl
custom_iam_bindings = [
  {
    member = "group:developers@example.com"
    role   = "roles/viewer"
    condition = {
      title      = "Development Environment Only"
      expression = "resource.type == 'compute.instance' && resource.labels.env == 'dev'"
    }
  }
]
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
| service_accounts | List of service accounts | `list(object)` | `[]` | no |
| custom_iam_bindings | Custom IAM bindings | `list(object)` | `[]` | no |
| create_gke_node_service_account | Create GKE node SA | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| service_accounts | Map of service account details |
| service_account_emails | Map of service account emails |
| service_account_keys | Service account private keys (sensitive) |
| gke_node_service_account_email | GKE node SA email |

## Notes

- **Service Account Keys**: Only generate keys when necessary, prefer Workload Identity
- **Least Privilege**: Grant minimal required permissions to service accounts
- **GKE Nodes**: Use dedicated service account with logging and monitoring roles
- **Conditional Access**: Use IAM conditions for fine-grained access control
- **Key Rotation**: Implement key rotation policy for service account keys

## Standard GKE Node Roles

When `create_gke_node_service_account = true`, the following roles are automatically assigned:

- `roles/logging.logWriter` - Write logs to Cloud Logging
- `roles/monitoring.metricWriter` - Write metrics to Cloud Monitoring
- `roles/monitoring.viewer` - View monitoring data
- `roles/artifactregistry.reader` - Pull container images from Artifact Registry

## Best Practices

1. **Use Workload Identity** for GKE workloads instead of service account keys
2. **Enable service account key rotation** if keys must be used
3. **Use separate service accounts** for different applications and environments
4. **Apply least privilege principle** - grant only necessary permissions
5. **Use IAM conditions** for time-based or resource-based access control
6. **Monitor service account usage** with Cloud Logging and audit logs
