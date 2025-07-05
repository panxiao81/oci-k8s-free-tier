# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform project that deploys a production-ready Kubernetes cluster (OKE) on Oracle Cloud Infrastructure's Always Free tier with comprehensive OAuth2 authentication, monitoring, and automated TLS certificate management using cert-manager and Cloudflare DNS-01 challenges.

## Key Infrastructure Components

- **OCI Kubernetes Engine (OKE)**: Managed Kubernetes cluster with 2 ARM-based nodes (VM.Standard.A1.Flex)
- **Network**: VCN with public/private subnets, NAT gateway, and service gateway
- **Load Balancer**: OCI Network Load Balancer (NLB) for ingress traffic
- **TLS Management**: cert-manager with Let's Encrypt (staging and production issuers)
- **Ingress**: NGINX Ingress Controller for L7 traffic routing
- **Storage**: JuiceFS distributed file system using OCI Object Storage and MySQL
- **Identity Management**: Kanidm OIDC provider for centralized authentication
- **Monitoring**: Victoria Metrics + Grafana + OpenTelemetry Collector for observability
- **External Authentication**: oauth2-proxy for protecting non-OAuth2 applications

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
terraform output grafana_admin_password

# Access passwords from Kubernetes secret (if mysql-passwords secret exists)
kubectl get secret mysql-passwords -o jsonpath='{.data.admin_password}' | base64 -d

# Reset Kanidm admin password for initial setup
kubectl exec -n kanidm $(kubectl get pods -n kanidm -l app=kanidm -o name) -- kanidmd recover-account -c /data/server.toml idm_admin
```

## Configuration Files

- **Backend**: Configure `backend.hcl` with OCI Object Storage details
- **Variables**: Configure `terraform.tfvars` with:
  - `compartment_id`: OCI compartment OCID
  - `region`: OCI region
  - `ssh_public_key`: SSH public key for node access
  - `base_domain`: Base domain for all services (e.g., "example.com")
  - `admin_subdomain`: Admin subdomain for administrative services (default: "admin")
  - `cloudflare_api_token`: Cloudflare API token for DNS-01 challenges
  - `letsencrypt_email`: Email for Let's Encrypt certificate registration
  - `kanidm_domain`: Domain name for Kanidm authentication service
  - `juicefs_bucket_name`: Object Storage bucket name for JuiceFS
  - `grafana_oauth_client_secret`: OAuth2 client secret for Grafana authentication
  - `oauth2_proxy_client_id`: OAuth2 client ID for oauth2-proxy (default: "juicefs-proxy")
  - `oauth2_proxy_client_secret`: OAuth2 client secret for oauth2-proxy authentication
  - `docker_hub_username`: Docker Hub username for image pull secrets
  - `docker_hub_password`: Docker Hub password or access token
  - `docker_hub_email`: Docker Hub email address
  - `object_storage_private_endpoint`: (Optional) Private endpoint URL for Object Storage

## Development Guidelines

- **New Variables**: When creating new Terraform variables, always update `terraform.tfvars.example` using the `<your_variable_name>` format for consistency
- **Customer Secret Keys**: For OCI S3-compatible API access, use Customer Secret Keys (not API keys). Credentials are stored in Kubernetes secrets for better security
- **Secrets Management**: Sensitive data like API keys are stored in Kubernetes secrets, not in terraform.tfvars files
- **OAuth2 Configuration**: Set up OAuth2 clients in Kanidm before applying Terraform configurations
- **Domain Variables**: Use domain variables instead of hardcoding domains for deployment flexibility
- **Private Endpoints**: Object Storage private endpoints must be created manually in OCI Console (no Terraform resource available)
- **Password Management**: All passwords automatically generated using `random_password` resources - no manual password management needed

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
- Certificate sharing between services on the same domain

### Authentication Architecture
- **Kanidm**: Central OIDC identity provider with ES256 token signing
- **Direct OAuth2**: Grafana integrates directly with Kanidm OIDC
- **External Auth**: oauth2-proxy protects non-OAuth2 applications via NGINX ingress
- **Group-based Access**: Uses `infra_admin@{kanidm_domain}` for authorization
- **PKCE Disabled**: oauth2-proxy configured without PKCE for compatibility

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
# Configure TLS with domain variables
# For OAuth2 protection, add external auth annotations:
# nginx.ingress.kubernetes.io/auth-url = "https://your-domain/oauth2/auth"
# nginx.ingress.kubernetes.io/auth-signin = "https://your-domain/oauth2/start?rd=$escaped_request_uri"
```

## Important Files

### Core Infrastructure
- `main.tf`: OKE cluster and node pool configuration
- `network.tf`: VCN and subnet configuration using oracle-terraform-modules/vcn
- `data.tf`: OCI data sources for availability domains
- `quota.tf`: Always Free tier quota enforcement policies

### Security & Authentication
- `kanidm.tf`: Kanidm OIDC identity provider deployment
- `oauth2-proxy.tf`: External authentication proxy for non-OAuth2 applications
- `docker-hub-secret.tf`: Docker registry secrets across all namespaces

### Networking & TLS
- `cert-manager.tf`: Helm chart deployment and ClusterIssuer setup
- `ingress-controller.tf`: NGINX Ingress Controller with OCI NLB annotations
- `dns.tf`: Cloudflare DNS record management with domain variables

### Storage & Data
- `juicefs.tf`: Distributed file system deployment with external auth
- `juicefs-iam.tf`: IAM policies for JuiceFS Object Storage access
- `passwords.tf`: Random password generation for all services

### Monitoring & Observability
- `victoria-stack.tf`: Victoria Metrics + Grafana with OAuth2 integration
- `otel-collector.tf`: OpenTelemetry Collector for metrics and logs
- `metrics-server.tf`: Kubernetes resource monitoring
- `otel-config.yaml.tpl`: OpenTelemetry configuration template

### Configuration
- `_variables.tf`: All Terraform variables and their defaults
- `terraform.tfvars.example`: Example configuration file
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

### OAuth2 Authentication Integration
**Problem**: Non-OAuth2 applications need protection with centralized authentication
**Solution**:
- Deploy oauth2-proxy as external authentication layer
- Use NGINX Ingress external auth annotations
- Configure group-based authorization with full Kanidm domain format
- Disable PKCE for application compatibility

### OAuth2-Proxy Cookie Secret Issues
**Problem**: Cookie secret validation fails with "must be 16, 24, or 32 bytes" error
**Solution**:
- Generate exactly 32-byte random password without base64 encoding
- Use raw `random_password.result` value directly in Kubernetes secret

## Operational Memory

### Key Services and Domains
- **Kanidm**: `kanidm` namespace, `auth.{kanidm_domain}` (e.g., auth.example.com)
- **Grafana**: `observability` namespace, `grafana.{admin_subdomain}.{base_domain}` (e.g., grafana.admin.example.com)
- **JuiceFS Dashboard**: `juicefs` namespace, `juicefs.{admin_subdomain}.{base_domain}` (e.g., juicefs.admin.example.com)
- **OAuth2-Proxy**: `juicefs` namespace, serves `/oauth2/*` endpoints for JuiceFS authentication
- **OpenTelemetry Collector**: `otel` namespace, internal service only

### Password Management Strategy
- All passwords automatically generated via `random_password` resources
- Stored in Kubernetes secrets for runtime access
- Terraform outputs available for administrative access
- No manual password management required

### Common Troubleshooting Steps
1. **OAuth2 Authentication Issues**: 
   - Check oauth2-proxy logs: `kubectl logs -n juicefs -l app.kubernetes.io/name=oauth2-proxy`
   - Verify user is in `infra_admin@{kanidm_domain}` group
   - Ensure OAuth2 client secret matches between Kanidm and Terraform
2. **JuiceFS Mount Issues**: Check CSI driver logs and MySQL connectivity
3. **Certificate Problems**: Verify DNS propagation and Cloudflare API token
4. **Pod Scheduling**: Check node resources and taints
5. **Service Access**: Use port forwarding or verify ingress configuration
6. **Kanidm Password Reset**: Use `kubectl exec` to run `kanidmd recover-account` command

### Development Patterns
- Create dedicated `.tf` files for each service
- Use existing patterns for secrets and configuration
- Add DNS records to `dns.tf` for new services using domain variables
- Configure ingress with cert-manager annotations and optional external auth
- Update `terraform.tfvars.example` for new variables
- Use `random_password` resources for all secret generation
- Deploy Docker Hub secrets to all namespaces for rate limit protection

### OAuth2 Setup Workflow
1. **Reset Kanidm admin password**: Use kubectl exec with `kanidmd recover-account`
2. **Create OAuth2 clients**: Use `kanidm system oauth2 create` for each application
3. **Configure redirect URLs**: Add proper callback URLs for each client
4. **Set up group mapping**: Map OAuth2 scopes to Kanidm groups
5. **Disable PKCE if needed**: Use `warning-insecure-client-disable-pkce` for compatibility
6. **Update Terraform variables**: Add client secrets to terraform.tfvars
7. **Apply infrastructure**: Run `terraform apply` to deploy with authentication

## Free Tier Resource Limits
- **Compute**: 2 OCPUs ARM instances (4 OCPUs total across 2 nodes)
- **Memory**: 12GB RAM across all nodes
- **Storage**: 20GB Object Storage + 50GB MySQL database
- **Network**: 10TB outbound data transfer per month
- **Load Balancer**: 1 Network Load Balancer included

## Project Evolution Notes
This project evolved from a basic OKE cluster to include:
1. **Core Infrastructure**: OKE cluster with ARM nodes and networking
2. **Storage Layer**: JuiceFS distributed filesystem with Object Storage + MySQL backend
3. **Identity Management**: Kanidm OIDC provider for centralized authentication
4. **Monitoring Stack**: Victoria Metrics + Grafana + OpenTelemetry Collector
5. **Security Layer**: OAuth2 authentication for all services via oauth2-proxy
6. **Automation**: Automated DNS management and certificate provisioning
7. **Observability**: Comprehensive metrics, logs, and monitoring
8. **Secret Management**: Automated password generation and secret distribution

The infrastructure is designed to be production-ready with enterprise-grade authentication, monitoring, and storage capabilities while staying within OCI's Always Free tier limits.

## Current Architecture Summary
- **Authentication**: Centralized OAuth2 via Kanidm protecting all administrative interfaces
- **Storage**: Distributed POSIX filesystem with automatic CSI provisioning
- **Monitoring**: Full observability stack with Grafana dashboards and metrics collection
- **Security**: TLS everywhere, group-based authorization, automated secret management
- **Scalability**: Container-ready with persistent storage and resource monitoring
- **Cost**: $0/month within Always Free tier limits with quota enforcement