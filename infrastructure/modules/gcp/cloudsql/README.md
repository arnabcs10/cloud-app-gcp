# GCP Cloud SQL Module

This module creates and manages Cloud SQL PostgreSQL instances with private networking and automated backups.

## Features

- **PostgreSQL Instance**: Fully managed PostgreSQL database
- **Private Networking**: VPC-native private IP connectivity
- **High Availability**: Regional instances with automatic failover
- **Automated Backups**: Point-in-time recovery and retention policies
- **Database Management**: Multiple databases and users
- **Security**: Private service connection, SSL encryption
- **Monitoring**: Query Insights and performance monitoring

## File Structure

```
cloudsql/
├── instance.tf                 # Cloud SQL instance and databases
├── private_service_connection.tf # Private networking notes
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
└── README.md                   # This file
```

## Usage Example

```hcl
module "cloudsql" {
  source = "./modules/gcp/cloudsql"

  project_id      = "my-gcp-project"
  instance_name   = "my-postgres"
  database_version = "POSTGRES_15"
  region          = "us-central1"
  tier            = "db-custom-2-7680"

  availability_type = "REGIONAL"
  disk_type        = "PD_SSD"
  disk_size        = 100

  # Private networking
  private_network         = module.network.vpc_self_link
  private_vpc_connection  = module.network.private_vpc_connection
  ipv4_enabled           = false

  # Backup configuration
  backup_enabled                 = true
  point_in_time_recovery_enabled = true
  backup_retention_count         = 7

  # Databases
  databases = [
    {
      name = "myapp"
    }
  ]

  # Users
  create_default_user = true
  default_user_name   = "postgres"

  users = [
    {
      name = "app_user"
    }
  ]

  depends_on = [module.network]
}
```

## Requirements

| Name | Version |
|------|----------|
| terraform | >= 1.0 |
| google | >= 4.0 |
| random | >= 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID | `string` | n/a | yes |
| instance_name | Name for the Cloud SQL instance | `string` | n/a | yes |
| region | The region for the instance | `string` | n/a | yes |
| private_network | VPC network for private IP | `string` | n/a | yes |
| database_version | PostgreSQL version | `string` | `"POSTGRES_15"` | no |
| tier | Machine tier | `string` | `"db-f1-micro"` | no |
| availability_type | ZONAL or REGIONAL | `string` | `"ZONAL"` | no |
| databases | List of databases to create | `list(object)` | `[]` | no |
| users | List of users to create | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | The ID of the Cloud SQL instance |
| instance_connection_name | Connection name for the instance |
| instance_private_ip_address | Private IP address |
| databases | Map of database details |
| default_user_password | Auto-generated password (sensitive) |

## Notes

- **Private Service Connection**: Must be created at the VPC level (network module)
- **Deletion Protection**: Enabled by default to prevent accidental deletion
- **Password Management**: Use auto-generated passwords or manage via secret manager
- **High Availability**: Use REGIONAL availability type for production workloads
- **Backups**: Point-in-time recovery requires transaction log retention
- **Instance Naming**: Instance names cannot be reused for 7 days after deletion

## Database Flags Example

```hcl
database_flags = [
  {
    name  = "max_connections"
    value = "200"
  },
  {
    name  = "shared_buffers"
    value = "262144"  # 256MB in 8KB blocks
  }
]
```
