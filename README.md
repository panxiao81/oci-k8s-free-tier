# OCI Kubernetes Free Tier Infrastructure

A complete Terraform-managed Kubernetes infrastructure on Oracle Cloud Infrastructure's Always Free tier, featuring distributed storage, identity management, and observability.

## Architecture Overview

This project deploys a production-ready Kubernetes cluster with:

- **Kubernetes**: OKE (Oracle Kubernetes Engine) with ARM-based nodes
- **Storage**: JuiceFS distributed file system with OCI Object Storage
- **Identity**: Kanidm authentication and authorization
- **Observability**: OpenTelemetry Collector for metrics and logs
- **TLS**: Automated certificate management with cert-manager and Let's Encrypt
- **DNS**: Cloudflare integration for automatic DNS management

## Features

### 🆓 Always Free Tier Optimized
- ARM-based instances (VM.Standard.A1.Flex)
- 2 OCPUs, 12GB RAM across worker nodes
- 50GB Object Storage and MySQL database
- Network Load Balancer with quota policies

### 🔐 Security & Identity
- Kanidm identity management with TLS passthrough
- Automated password generation and Kubernetes secrets
- Customer Secret Keys for secure Object Storage access
- Let's Encrypt certificates with DNS-01 validation

### 💾 Distributed Storage
- JuiceFS POSIX-compliant distributed file system
- OCI Object Storage backend with S3-compatible API
- MySQL metadata store with automated user management
- Dynamic PVC provisioning via CSI driver

### 📊 Observability
- OpenTelemetry Collector for unified telemetry
- Console exporter for debugging (easily configurable)
- Ready for integration with monitoring backends

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

3. **Configure variables** (create `terraform.tfvars`):
   ```hcl
   # OCI Configuration
   compartment_id = "ocid1.compartment.oc1.."
   region = "us-ashburn-1"
   ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."
   
   # Cloudflare DNS
   cloudflare_api_token = "your-cloudflare-token"
   
   # Let's Encrypt
   letsencrypt_email = "your-email@example.com"
   
   # Services
   kanidm_domain = "auth.yourdomain.com"
   juicefs_bucket_name = "your-juicefs-bucket"
   
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

| Service | Namespace | Domain | Purpose |
|---------|-----------|---------|---------|
| Kanidm | `kanidm` | `auth.yourdomain.com` | Identity Management |
| JuiceFS Dashboard | `juicefs` | `juicefs.admin.yourdomain.com` | Storage Management |
| OTel Collector | `otel` | N/A | Observability |

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

### Deploying Applications with TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
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
kubectl get secret mysql-passwords -o jsonpath='{.data.admin_password}' | base64 -d

# Scale applications
kubectl scale deployment my-app --replicas=3
```

### Storage Management
```bash
# List JuiceFS volumes
kubectl get pv | grep juicefs

# Check JuiceFS dashboard
kubectl port-forward -n juicefs svc/juicefs-dashboard 9567:9567
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

### Logs
```bash
# JuiceFS CSI driver
kubectl logs -n juicefs -l app.kubernetes.io/name=juicefs-csi-driver

# cert-manager
kubectl logs -n cert-manager -l app=cert-manager

# NGINX Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx
```

### Common Issues

1. **Certificate not issued**: Check DNS propagation and Cloudflare API token
2. **JuiceFS mount failures**: Verify MySQL connectivity and credentials
3. **Pod scheduling issues**: Check node resources and taints

## Cost Optimization

This infrastructure is designed to run within OCI's Always Free tier limits:

- **Compute**: 2 OCPUs ARM instances (4 OCPUs total across 2 nodes)
- **Storage**: 20GB Object Storage + 50GB MySQL
- **Network**: 10TB outbound data transfer
- **Load Balancer**: 1 Network Load Balancer

## Security Considerations

- All secrets are managed via Kubernetes and Terraform
- TLS termination at ingress level
- Private subnet for worker nodes
- Customer Secret Keys for Object Storage access
- MySQL accessible only from private subnet

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
