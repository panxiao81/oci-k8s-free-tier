# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform project that deploys a Kubernetes cluster (OKE) on Oracle Cloud Infrastructure's Always Free tier with automated TLS certificate management using cert-manager and Cloudflare DNS-01 challenges.

## Key Infrastructure Components

- **OCI Kubernetes Engine (OKE)**: Managed Kubernetes cluster with 2 ARM-based nodes (VM.Standard.A1.Flex)
- **Network**: VCN with public/private subnets, NAT gateway, and service gateway
- **Load Balancer**: OCI Network Load Balancer (NLB) for ingress traffic
- **TLS Management**: cert-manager with Let's Encrypt (staging and production issuers)
- **Ingress**: NGINX Ingress Controller for L7 traffic routing
- **Storage**: JuiceFS distributed file system using OCI Object Storage and MySQL
- **Identity Management**: Kanidm for authentication and authorization

## Common Commands

All commands should be run from the `infra/` directory:

```bash
# Initialize Terraform with remote backend
make init
# or
terraform init -backend-config=backend.hcl

# Plan changes
terraform plan

# Apply infrastructure changes
terraform apply

# Destroy infrastructure
terraform destroy

# Get kubeconfig (generated after apply)
export KUBECONFIG=./kubeconfig
kubectl get nodes

# View generated passwords (if needed for troubleshooting)
terraform output mysql_admin_password
terraform output juicefs_mysql_password

# Access passwords from Kubernetes secret
kubectl get secret mysql-passwords -o jsonpath='{.data.admin_password}' | base64 -d
```

## Configuration Files

- **Backend**: Configure `backend.hcl` with OCI Object Storage details
- **Variables**: Configure `terraform.tfvars` with:
  - `compartment_id`: OCI compartment OCID
  - `region`: OCI region
  - `ssh_public_key`: SSH public key for node access
  - `cloudflare_api_token`: Cloudflare API token for DNS-01 challenges
  - `letsencrypt_email`: Email for Let's Encrypt certificate registration
  - `kanidm_domain`: Domain name for Kanidm authentication service
  - `juicefs_bucket_name`: Object Storage bucket name for JuiceFS
  - `object_storage_private_endpoint`: (Optional) Private endpoint URL for Object Storage

## Development Guidelines

- **New Variables**: When creating new Terraform variables, always update `terraform.tfvars.example` using the `<your_variable_name>` format for consistency
- **Customer Secret Keys**: For OCI S3-compatible API access, use Customer Secret Keys (not API keys). Credentials are stored in Kubernetes secrets for better security
- **Secrets Management**: Sensitive data like API keys are stored in Kubernetes secrets, not in terraform.tfvars files
- **Private Endpoints**: Object Storage private endpoints must be created manually in OCI Console (no Terraform resource available)
- **Password Management**: Database passwords are automatically generated using `random_password` resources - no manual password management needed

## Architecture Notes

### Network Design
- VCN CIDR: 10.0.0.0/16
- Public subnet: 10.0.0.0/24 (API server, load balancer)
- Private subnet: 10.0.1.0/24 (worker nodes, pods)
- Pod CIDR: 10.244.0.0/16
- Service CIDR: 10.96.0.0/16

### Always Free Tier Constraints
- Uses quota policies in `quota.tf` to enforce free tier limits
- ARM-based instances only (VM.Standard.A1.Flex)
- 2 OCPUs, 12GB RAM total across nodes
- 50GB boot volume per node

### Certificate Management
- Two ClusterIssuers: `letsencrypt-staging` and `letsencrypt-prod`
- Uses Cloudflare DNS-01 solver for wildcard certificates
- Automatic certificate provisioning via ingress annotations

### Storage Architecture
- **JuiceFS**: Distributed POSIX-compliant file system
- **Backend**: OCI Object Storage (20GB free tier) + OCI MySQL (50GB free tier)
- **CSI Driver**: Provides dynamic PVC provisioning with `juicefs-sc` storage class
- **Security**: Dedicated IAM user with Customer Secret Keys stored in Kubernetes secrets
- **Automation**: Object Storage namespace automatically discovered via data source
- **Password Generation**: All database passwords automatically generated and stored securely

## Deploying Applications

Create new `.tf` files for applications using this pattern:

```terraform
# Use cert-manager.io/cluster-issuer annotation with "letsencrypt-staging" or "letsencrypt-prod"
# Set ingress_class_name = "nginx"
# Configure TLS with your domain
```

## Important Files

- `main.tf`: OKE cluster and node pool configuration
- `network.tf`: VCN and subnet configuration using oracle-terraform-modules/vcn
- `cert-manager.tf`: Helm chart deployment and ClusterIssuer setup
- `ingress-controller.tf`: NGINX Ingress Controller with OCI NLB annotations
- `quota.tf`: Free tier quota enforcement
- `node-init.sh`: Kubernetes node initialization script

## Terraform Providers

- `oracle/oci`: ~> 6.21.0 for OCI resources
- `hashicorp/helm`: ~> 3.0.2 for Kubernetes applications
- `hashicorp/local`: ~> 2.5.1 for local file generation
- `cloudflare/cloudflare`: ~> 4.31.0 for DNS management

## Security Considerations

- Sensitive variables (API tokens) are marked as sensitive in Terraform
- Use `.tfvars` files (gitignored) for secrets
- SSH access to nodes requires private key corresponding to `ssh_public_key`
- Cluster API server is publicly accessible but secured with RBAC

## Technical Challenges and Solutions

### MySQL Password URL Encoding Issues
**Problem**: JuiceFS connection strings break when MySQL passwords contain special characters (particularly `@`)
**Solution**: 
- Added `keepers` block in `passwords.tf` to force password regeneration
- Configure MySQL with relaxed password validation policies
- Use URL-safe password generation in Terraform

### Docker Hub Rate Limiting
**Problem**: Container pulls fail due to Docker Hub rate limits
**Solution**: 
- Configure `imagePullSecrets` in deployments
- Set `imagePullPolicy: IfNotPresent` to reduce pulls
- Use existing `docker-hub` secret for authentication

### Object Storage Authentication
**Problem**: Complex S3-compatible API integration with proper authentication
**Solution**:
- Use Customer Secret Keys instead of API keys for S3 compatibility
- Automated namespace discovery via data sources
- Proper IAM permissions for Object Storage access

## Operational Memory

### Key Services and Domains
- **Kanidm**: `kanidm` namespace, `auth.yourdomain.com` domain
- **JuiceFS Dashboard**: `juicefs` namespace, `juicefs.admin.yourdomain.com` domain
- **OpenTelemetry Collector**: `otel` namespace, internal service only

### Password Management Strategy
- All passwords automatically generated via `random_password` resources
- Stored in Kubernetes secrets for runtime access
- Terraform outputs available for administrative access
- No manual password management required

### Common Troubleshooting Steps
1. **JuiceFS Mount Issues**: Check CSI driver logs and MySQL connectivity
2. **Certificate Problems**: Verify DNS propagation and Cloudflare API token
3. **Pod Scheduling**: Check node resources and taints
4. **Service Access**: Use port forwarding or verify ingress configuration

### Development Patterns
- Create dedicated `.tf` files for each service
- Use existing patterns for secrets and configuration
- Add DNS records to `dns.tf` for new services
- Configure ingress with cert-manager annotations
- Update `terraform.tfvars.example` for new variables

## Free Tier Resource Limits
- **Compute**: 2 OCPUs ARM instances (4 OCPUs total across 2 nodes)
- **Memory**: 12GB RAM across all nodes
- **Storage**: 20GB Object Storage + 50GB MySQL database
- **Network**: 10TB outbound data transfer per month
- **Load Balancer**: 1 Network Load Balancer included

## Project Evolution Notes
This project evolved from a basic OKE cluster to include:
1. OpenTelemetry Collector for observability
2. Kanidm for identity management
3. JuiceFS for distributed storage
4. MySQL backend for JuiceFS metadata
5. Automated DNS management
6. Comprehensive password and secret management

The infrastructure is designed to be production-ready while staying within OCI's Always Free tier limits.