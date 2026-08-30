# Production Environment

This directory contains the Terraform configuration for the **production** environment of the cloud-app-gcp project.

## Overview

The production environment deploys a complete GCP infrastructure stack including:

- **VPC Network**: Private network with subnets and Cloud NAT
- **GKE Cluster**: Regional Kubernetes cluster with multiple node pools
- **Cloud SQL**: High-availability PostgreSQL database
- **IAM**: Service accounts with Workload Identity integration

## Architecture

```
Production Environment
├── VPC Network (cloud-app-vpc-prd)
│   ├── GKE Subnet (10.0.0.0/24)
│   ├── Pod Secondary Range (10.1.0.0/16)
│   ├── Service Secondary Range (10.2.0.0/16)
│   ├── Cloud NAT
│   └── Firewall Rules
│
├── GKE Cluster (cloud-app-gke-prd)
│   ├── App Node Pool (2-10 nodes, e2-standard-4)
│   ├── System Node Pool (1-3 nodes, e2-medium)
│   └── Workload Identity (voting, results, worker apps)
│
├── Cloud SQL (cloud-app-postgres-prd)
│   ├── PostgreSQL 15
│   ├── Regional HA
│   ├── 100GB SSD
│   └── Automated Backups
│
└── IAM
    ├── GKE Node Service Account
    ├── Application Service Accounts
    └── Workload Identity Bindings
```

## File Structure

```
prd/
├── provider.tf                    # Terraform Cloud backend & GCP provider
├── variables.tf                   # Input variable definitions
├── terraform.tfvars               # Production variable values
├── network.tf                     # Network module configuration
├── iam.tf                         # IAM module configuration
├── gke.tf                         # GKE module configuration
├── cloudsql.tf                    # Cloud SQL module configuration
├── outputs.tf                     # Output values
├── TERRAFORM_CLOUD_SETUP.md       # Terraform Cloud setup guide
└── README.md                      # This file
```

## Prerequisites

### 1. Terraform Cloud Account

- Sign up at [app.terraform.io](https://app.terraform.io)
- Create organization
- Create workspace: `cloud-app-gcp-prd`

### 2. GCP Project

- Active GCP project with billing enabled
- Required APIs enabled (see setup guide)
- Service account created with appropriate permissions

### 3. GitHub Repository

- Code pushed to GitHub repository
- Connected to Terraform Cloud workspace

## Setup Instructions

### Quick Start

1. **Read the setup guide**:
   ```bash
   cat TERRAFORM_CLOUD_SETUP.md
   ```

2. **Update configuration files**:
   - Edit `terraform.tfvars` with your values
   - Update `provider.tf` with your Terraform Cloud organization name

3. **Configure Terraform Cloud**:
   - Follow instructions in `TERRAFORM_CLOUD_SETUP.md`
   - Set up GCP authentication
   - Configure workspace variables

4. **Deploy infrastructure**:
   - Push code to GitHub (auto-triggers run)
   - Or use `terraform apply` locally

### Detailed Setup

See **[TERRAFORM_CLOUD_SETUP.md](./TERRAFORM_CLOUD_SETUP.md)** for comprehensive setup instructions.

## Configuration

### Required Variables (terraform.tfvars)

Edit `terraform.tfvars` and update the following:

```hcl
# REQUIRED: Update with your GCP project ID
project_id = "your-gcp-project-id"

# REQUIRED: Add your IP addresses for kubectl access
master_authorized_networks = [
  {
    cidr_block   = "YOUR_IP/32"
    display_name = "Your Location"
  }
]
```

### Terraform Cloud Variables

Configure in Terraform Cloud workspace:

**Environment Variables**:
- `GOOGLE_CREDENTIALS` (sensitive) - Service account JSON key
- `GOOGLE_PROJECT` - GCP project ID
- `GOOGLE_REGION` - Default region

**Terraform Variables**:
- `project_id` - GCP project ID
- `master_authorized_networks` (HCL) - Authorized networks for GKE

## Deployment

### Option 1: Automatic (Recommended)

```bash
# Make changes
vi terraform.tfvars

# Commit and push
git add .
git commit -m "Update production configuration"
git push origin main

# Terraform Cloud will automatically:
# 1. Queue run
# 2. Execute plan
# 3. Wait for approval
# 4. Apply changes (after approval)
```

### Option 2: Manual via CLI

```bash
# Navigate to production directory
cd infrastructure/envs/prd

# Login to Terraform Cloud
terraform login

# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply
```

## Resource Costs (Estimated Monthly)

| Resource | Configuration | Estimated Cost |
|----------|---------------|----------------|
| **GKE Cluster** | 1 regional cluster | $74/month |
| **GKE Nodes** | 2-10 e2-standard-4 nodes | $120-$600/month |
| **Cloud SQL** | db-custom-2-7680 (REGIONAL) | $280/month |
| **Cloud NAT** | 1 gateway | $45/month |
| **Networking** | VPC, Load Balancers | $20-$50/month |
| **Storage** | Disk, backups | $20-$40/month |
| **Total** | - | **~$559-$1,089/month** |

*Costs are estimates and may vary based on usage*

## Outputs

After successful deployment, you can access outputs:

```bash
# View all outputs
terraform output

# View specific output
terraform output gke_cluster_name

# Get kubectl config command
terraform output -raw gke_kubectl_config_command
```

### Key Outputs

- **GKE Cluster Endpoint**: Kubernetes API endpoint
- **Cloud SQL Connection Name**: For Cloud SQL proxy
- **Service Account Emails**: For application configuration
- **Connection Instructions**: Step-by-step connection guide

## Operations

### Connect to GKE Cluster

```bash
# Get kubectl config command from outputs
terraform output -raw gke_kubectl_config_command | bash

# Or manually
gcloud container clusters get-credentials cloud-app-gke-prd \
  --region=us-central1 \
  --project=YOUR_PROJECT_ID

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Connect to Cloud SQL

```bash
# Get connection details
terraform output cloudsql_connection_info

# Using Cloud SQL Proxy (from local machine)
cloud_sql_proxy -instances=CONNECTION_NAME=tcp:5432

# Connect with psql
psql -h 127.0.0.1 -U postgres -d voting_app

# From GKE pod (using Workload Identity)
psql -h PRIVATE_IP -U postgres -d voting_app
```

### Get Database Password

```bash
# View auto-generated postgres password
terraform output -raw cloudsql_default_user_password

# Store in Secret Manager (recommended)
gcloud secrets create postgres-password \
  --data-file=<(terraform output -raw cloudsql_default_user_password)
```

## Monitoring & Logging

### Cloud Logging

```bash
# View GKE cluster logs
gcloud logging read "resource.type=k8s_cluster" --limit 50

# View Cloud SQL logs
gcloud logging read "resource.type=cloudsql_database" --limit 50
```

### Cloud Monitoring

- Navigate to [Cloud Console Monitoring](https://console.cloud.google.com/monitoring)
- View dashboards for GKE and Cloud SQL
- Set up alerts for resource utilization

## Maintenance

### Regular Tasks

- ✅ **Review costs**: Monthly cost analysis
- ✅ **Update dependencies**: Terraform provider versions
- ✅ **Rotate credentials**: Service account keys (every 90 days)
- ✅ **Review IAM**: Service account permissions
- ✅ **Monitor backups**: Verify Cloud SQL backups
- ✅ **GKE upgrades**: Review and apply cluster upgrades

### Upgrade GKE Cluster

```bash
# Check available versions
gcloud container get-server-config --region=us-central1

# Upgrade via Terraform (recommended)
# Update release_channel in gke.tf if needed
terraform plan
terraform apply
```

## Disaster Recovery

### Backup Strategy

1. **Terraform State**: Managed by Terraform Cloud (versioned, encrypted)
2. **Cloud SQL**: Automated daily backups (7-day retention)
3. **GKE Configuration**: Infrastructure as Code in Git

### Recovery Procedure

```bash
# Restore from Terraform state
terraform plan  # Review current vs. desired state
terraform apply # Recreate infrastructure

# Restore Cloud SQL from backup (via Console or gcloud)
gcloud sql backups list --instance=INSTANCE_NAME
gcloud sql backups restore BACKUP_ID --backup-instance=INSTANCE_NAME
```

## Security

### Security Features

- ✅ Private GKE cluster with authorized networks
- ✅ Cloud SQL private IP only
- ✅ Workload Identity for pod-to-GCP authentication
- ✅ Shielded GKE nodes
- ✅ Network policies enabled
- ✅ VPC Flow Logs for monitoring
- ✅ Encrypted Terraform state

### Security Checklist

- [ ] MFA enabled for all Terraform Cloud users
- [ ] Service account keys rotated regularly
- [ ] Master authorized networks configured
- [ ] Cloud SQL deletion protection enabled
- [ ] GKE cluster deletion protection enabled
- [ ] Firewall rules reviewed
- [ ] IAM permissions follow least privilege

## Troubleshooting

### Common Issues

**Issue**: `Error: google: could not find default credentials`

**Solution**: Verify `GOOGLE_CREDENTIALS` in Terraform Cloud workspace variables

---

**Issue**: `Error: Error waiting for creating GKE cluster: timeout`

**Solution**: Increase timeout values in `gke.tf` or check GCP quotas

---

**Issue**: kubectl connection refused

**Solution**: Add your IP to `master_authorized_networks` in `terraform.tfvars`

---

**Issue**: Cloud SQL connection timeout

**Solution**: Verify private service connection and VPC peering

## Support

For issues or questions:

1. Check [TERRAFORM_CLOUD_SETUP.md](./TERRAFORM_CLOUD_SETUP.md)
2. Review Terraform Cloud run logs
3. Check GCP Cloud Logging
4. Contact DevOps team

## Contributing

1. Create feature branch
2. Make changes
3. Test in dev environment first
4. Create Pull Request
5. Review speculative plan
6. Merge after approval
7. Approve production run

## License

Internal use only - Proprietary
