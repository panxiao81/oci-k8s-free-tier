# OCI Kubernetes Free Tier Infrastructure

This project provides Terraform code to set up a Kubernetes cluster (OKE) on Oracle Cloud Infrastructure's (OCI) Always Free tier. It includes automated TLS certificate management using `cert-manager` and Cloudflare.

## Features

- **OCI Kubernetes Engine (OKE):** A managed Kubernetes service.
- **Remote State:** Terraform state is stored securely in an OCI Object Storage bucket.
- **NGINX Ingress Controller:** Manages external access to the services in your cluster.
- **Automated HTTPS:** `cert-manager` is configured to automatically issue and renew free, trusted TLS certificates from Let's Encrypt using Cloudflare for DNS-01 challenges.
- **Free Tier Quotas:** Includes a quota policy to help prevent accidental charges by enforcing Always Free tier limits for the Network Load Balancer.

## Prerequisites

Before you begin, ensure you have the following:

- An OCI account with the CLI configured.
- Terraform installed.
- A domain name managed by Cloudflare.
- A Cloudflare API Token with `Zone:Zone:Read` and `Zone:DNS:Edit` permissions.

## Setup

1.  **Clone the repository:**
    ```bash
    git clone <your-repo-url>
    cd oci-k8s-free-tier/infra
    ```

2.  **Configure Terraform Backend:**
    -   Rename `backend.hcl.example` to `backend.hcl`.
    -   Update the file with your OCI region and Object Storage namespace.

3.  **Configure Terraform Variables:**
    -   Rename `terraform.tfvars.example` to `terraform.tfvars`.
    -   Fill in the required values:
        -   `region`: Your OCI region.
        -   `compartment_id`: The OCID of your compartment.
        -   `ssh_public_key`: Your public SSH key.
        -   `cloudflare_api_token`: Your Cloudflare API token.
        -   `letsencrypt_email`: The email address for Let's Encrypt registration.

## Usage

1.  **Initialize Terraform:**
    ```bash
    make init
    ```
    Alternatively, you can run the full command:
    ```bash
    terraform init -backend-config=backend.hcl
    ```

2.  **Deploy the infrastructure:**
    ```bash
    terraform apply
    ```

3.  **Destroy the infrastructure:**
    ```bash
    terraform destroy
    ```

## Deploying an Application

To deploy an application and secure it with an HTTPS certificate, create a new `.tf` file (e.g., `my-app.tf`) with a deployment, service, and ingress resource.

Here is an example:

```terraform
resource "kubernetes_deployment" "my_app" {
  metadata {
    name = "my-app"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "my-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "my-app"
        }
      }
      spec {
        container {
          image = "nginx"
          name  = "my-app"
        }
      }
    }
  }
}

resource "kubernetes_service" "my_app" {
  metadata {
    name = "my-app"
  }
  spec {
    selector = {
      app = "my-app"
    }
    port {
      port        = 80
    }
  }
}

resource "kubernetes_ingress_v1" "my_app_ingress" {
  metadata {
    name = "my-app-ingress"
    annotations = {
      // Use 'letsencrypt-prod' for trusted certificates
      // or 'letsencrypt-staging' for testing.
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts      = ["your.domain.com"]
      secret_name = "my-app-tls"
    }
    rule {
      host = "your.domain.com"
      http {
        paths {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "my-app"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
```

Replace `your.domain.com` with your actual domain. When you run `terraform apply`, `cert-manager` will automatically obtain a certificate for your domain.

> This repo is fully powered by Gimini code assist and Gimini CLI!
>
> AI Powered!
