terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.21.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 4.31.0"
    }
  }
}

provider "oci" {
  region = var.region
}

provider "helm" {
  kubernetes = {
    config_path = "./kubeconfig"
  }
}

provider "kubernetes" {
  config_path = "./kubeconfig"
}
