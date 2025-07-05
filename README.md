# OCI Kubernetes Free Tier Infrastructure

A complete Terraform-managed Kubernetes infrastructure on Oracle Cloud Infrastructure's Always Free tier, featuring OAuth2 authentication, distributed storage, comprehensive monitoring, and automated security.

## Architecture Overview

This project deploys a production-ready Kubernetes cluster with:

- **Kubernetes**: OKE (Oracle Kubernetes Engine) with ARM-based nodes
- **Authentication**: Kanidm OIDC provider with oauth2-proxy for unified login
- **Storage**: JuiceFS distributed file system with OCI Object Storage backend
- **Monitoring**: Victoria Metrics + Grafana + OpenTelemetry Collector stack
- **Security**: OAuth2 authentication protecting all administrative interfaces
- **TLS**: Automated certificate management with cert-manager and Let's Encrypt
- **DNS**: Cloudflare integration with configurable domain management

## Features

### 🆓 Always Free Tier Optimized
- ARM-based instances (VM.Standard.A1.Flex)
- 2 OCPUs, 12GB RAM across worker nodes
- 50GB Object Storage and MySQL database
- Network Load Balancer with quota policies

### 🔐 Security & Authentication
- **Centralized OAuth2**: Kanidm OIDC provider with ES256 token signing
- **External Authentication**: oauth2-proxy protecting non-OAuth2 applications
- **Group-based Authorization**: Fine-grained access control via Kanidm groups
- **Automated Secrets**: Random password generation and secure distribution
- **TLS Everywhere**: Let's Encrypt certificates with DNS-01 validation
- **Secure Storage Access**: Customer Secret Keys for Object Storage integration

### 💾 Distributed Storage
- JuiceFS POSIX-compliant distributed file system
- OCI Object Storage backend with S3-compatible API
- MySQL metadata store with automated user management
- Dynamic PVC provisioning via CSI driver

### 📊 Monitoring & Observability
- **Victoria Metrics**: High-performance metrics storage and querying
- **Grafana**: Rich dashboards with OAuth2 authentication via Kanidm
- **OpenTelemetry Collector**: Unified metrics and logs collection
- **Metrics Server**: Kubernetes resource monitoring for HPA/VPA
- **Pre-built Dashboards**: Kubernetes cluster and pod monitoring ready

## Quick Start

### Prerequisites

1. **OCI Account**: Oracle Cloud Infrastructure account with Always Free tier
2. **Terraform**: Version 1.0 or later
3. **Cloudflare**: Domain with API token for DNS management
4. **SSH Key**: Public key for node access

### Configuration

1. **Clone and navigate to infrastructure directory**:
   ```bash
   git clone <repository-url>
   cd oci-k8s-free-tier/infra
   ```

2. **Configure backend storage** (create `backend.hcl`):
   ```hcl
   bucket = "your-terraform-state-bucket"
   key    = "terraform.tfstate"
   region = "us-ashburn-1"
   namespace = "your-object-storage-namespace"
   ```

3. **Configure variables** (create `terraform.tfvars` from `terraform.tfvars.example`):
   ```hcl
   # OCI Configuration
   compartment_id = "ocid1.compartment.oc1.."
   region = "us-ashburn-1"
   ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
   
   # Domain Configuration
   base_domain = "yourdomain.com"
   admin_subdomain = "admin"
   kanidm_domain = "auth.yourdomain.com"
   
   # Cloudflare DNS & TLS
   cloudflare_api_token = "your-cloudflare-token"
   letsencrypt_email = "your-email@example.com"
   
   # Storage
   juicefs_bucket_name = "your-juicefs-bucket"
   
   # OAuth2 Authentication (configure after Kanidm setup)
   grafana_oauth_client_secret = "your-grafana-oauth-secret"
   oauth2_proxy_client_id = "juicefs-proxy"
   oauth2_proxy_client_secret = "your-oauth2-proxy-secret"
   
   # Docker Hub (to avoid rate limiting)
   docker_hub_username = "your-docker-username"
   docker_hub_password = "your-docker-password"
   docker_hub_email = "your-email@example.com"
   
   # Optional
   object_storage_private_endpoint = "https://your-private-endpoint"
   ```

### Deployment

1. **Initialize Terraform**:
   ```bash
   make init
   # or
   terraform init -backend-config=backend.hcl
   ```

2. **Plan and apply**:
   ```bash
   terraform plan
   terraform apply
   ```

3. **Configure kubectl**:
   ```bash
   export KUBECONFIG=./kubeconfig
   kubectl get nodes
   ```

4. **Set up OAuth2 Authentication**:
   ```bash
   # Reset Kanidm admin password
   kubectl exec -n kanidm $(kubectl get pods -n kanidm -l app=kanidm -o name) -- \
     kanidmd recover-account -c /data/server.toml idm_admin
   
   # Create OAuth2 clients (use generated password)
   kanidm login -n idm_admin
   kanidm group create infra_admin
   kanidm person create <username> "<Full Name>"
   kanidm group add-members infra_admin <username>
   
   # Set up Grafana OAuth2
   kanidm system oauth2 create grafana "Grafana Dashboard" "https://grafana.admin.yourdomain.com/"
   kanidm system oauth2 add-redirect-url grafana "https://grafana.admin.yourdomain.com/login/generic_oauth"
   kanidm system oauth2 update-scope-map grafana infra_admin openid profile email groups
   kanidm system oauth2 warning-insecure-client-disable-pkce grafana
   
   # Set up JuiceFS OAuth2 proxy
   kanidm system oauth2 create juicefs-proxy "JuiceFS Dashboard Proxy" "https://juicefs.admin.yourdomain.com/"
   kanidm system oauth2 add-redirect-url juicefs-proxy "https://juicefs.admin.yourdomain.com/oauth2/callback"
   kanidm system oauth2 update-scope-map juicefs-proxy infra_admin openid profile email groups
   kanidm system oauth2 warning-insecure-client-disable-pkce juicefs-proxy
   
   # Get client secrets and update terraform.tfvars
   kanidm system oauth2 show-basic-secret grafana
   kanidm system oauth2 show-basic-secret juicefs-proxy
   
   # Apply OAuth2 configuration
   terraform apply
   ```

## Infrastructure Components

### Network Architecture
```
VCN (10.0.0.0/16)
├── Public Subnet (10.0.0.0/24)
│   ├── API Server
│   └── Network Load Balancer
└── Private Subnet (10.0.1.0/24)
    ├── Worker Nodes
    └── Pods (10.244.0.0/16)
```

### Storage Stack
```
Applications
    ↓
JuiceFS CSI Driver
    ↓
JuiceFS Client
    ↓
┌─────────────────┬─────────────────┐
│   OCI Object    │   MySQL         │
│   Storage       │   Metadata      │
│   (Data)        │   (Filesystem)  │
└─────────────────┴─────────────────┘
```

### Key Services

| Service | Namespace | Domain | Purpose | Authentication |
|---------|-----------|---------|---------|----------------|
| Kanidm | `kanidm` | `auth.yourdomain.com` | OIDC Identity Provider | Built-in |
| Grafana | `observability` | `grafana.admin.yourdomain.com` | Monitoring Dashboards | OAuth2 via Kanidm |
| JuiceFS Dashboard | `juicefs` | `juicefs.admin.yourdomain.com` | Storage Management | OAuth2 via oauth2-proxy |
| Victoria Metrics | `observability` | N/A | Metrics Storage | Internal |
| OTel Collector | `otel` | N/A | Telemetry Collection | Internal |

## Usage Examples

### Using JuiceFS Storage

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: juicefs-sc
  resources:
    requests:
      storage: 10Gi
```

### Deploying Applications with TLS and OAuth2 Protection

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # Optional: Add OAuth2 protection via external auth
    nginx.ingress.kubernetes.io/auth-url: "https://juicefs.admin.yourdomain.com/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://juicefs.admin.yourdomain.com/oauth2/start?rd=$escaped_request_uri"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.yourdomain.com
      secretName: app-tls
  rules:
    - host: app.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Management Commands

### Cluster Operations
```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Access generated passwords
terraform output mysql_admin_password
terraform output grafana_admin_password
kubectl get secret mysql-passwords -o jsonpath='{.data.admin_password}' | base64 -d

# Scale applications
kubectl scale deployment my-app --replicas=3
```

### Storage Management
```bash
# List JuiceFS volumes
kubectl get pv | grep juicefs

# Access JuiceFS dashboard (OAuth2 protected)
open https://juicefs.admin.yourdomain.com

# Or port-forward for debugging
kubectl port-forward -n juicefs svc/juicefs-csi-dashboard 8088:8088
```

### Certificate Management
```bash
# Check certificate status
kubectl get certificates -A
kubectl describe certificate app-tls

# Force certificate renewal
kubectl delete certificate app-tls
```

## Monitoring & Troubleshooting

### Access Monitoring Stack
```bash
# Access Grafana (OAuth2 protected)
open https://grafana.admin.yourdomain.com

# Port-forward for debugging
kubectl port-forward -n observability svc/grafana 3000:80
```

### Logs
```bash
# OAuth2 authentication
kubectl logs -n juicefs -l app.kubernetes.io/name=oauth2-proxy
kubectl logs -n kanidm -l app=kanidm

# JuiceFS CSI driver
kubectl logs -n juicefs -l app.kubernetes.io/name=juicefs-csi-driver

# Monitoring stack
kubectl logs -n observability -l app.kubernetes.io/name=grafana
kubectl logs -n observability -l app.kubernetes.io/name=victoria-metrics

# cert-manager
kubectl logs -n cert-manager -l app=cert-manager

# NGINX Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Common Issues

1. **OAuth2 authentication failures**: 
   - Check user is in `infra_admin@auth.yourdomain.com` group
   - Verify OAuth2 client secrets match between Kanidm and Terraform
   - Check oauth2-proxy logs for detailed errors

2. **Certificate not issued**: Check DNS propagation and Cloudflare API token

3. **JuiceFS mount failures**: Verify MySQL connectivity and credentials

4. **Pod scheduling issues**: Check node resources and taints

5. **Grafana login issues**: Ensure OAuth2 client is properly configured in Kanidm

## Cost Optimization

This infrastructure is designed to run within OCI's Always Free tier limits:

- **Compute**: 2 OCPUs ARM instances (4 OCPUs total across 2 nodes)
- **Storage**: 20GB Object Storage + 50GB MySQL
- **Network**: 10TB outbound data transfer
- **Load Balancer**: 1 Network Load Balancer

## Security Considerations

- **Centralized Authentication**: All administrative interfaces protected by OAuth2
- **Zero-Trust Network**: External authentication via oauth2-proxy
- **Automated Secrets**: All passwords generated and managed automatically
- **TLS Everywhere**: End-to-end encryption with Let's Encrypt certificates
- **Network Isolation**: Private subnet for worker nodes and databases
- **Secure Storage**: Customer Secret Keys for Object Storage access
- **Group-based Authorization**: Fine-grained access control via Kanidm groups

## Contributing

1. Follow existing Terraform patterns and conventions
2. Update `terraform.tfvars.example` when adding new variables
3. Test changes in staging environment first
4. Document any architectural changes

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Check the troubleshooting section above
- Review Terraform logs: `terraform apply -debug`
- Examine Kubernetes events: `kubectl get events -A`
