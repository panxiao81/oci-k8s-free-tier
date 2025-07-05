variable "compartment_id" {
}

variable "region" {
}

variable "ssh_public_key" {
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "letsencrypt_email" {
  type = string
}

variable "base_domain" {
  type        = string
  description = "Base domain name for all services"
  default     = "example.com"
}

variable "admin_subdomain" {
  type        = string
  description = "Admin subdomain for administrative services"
  default     = "admin"
}

variable "kanidm_domain" {
  type        = string
  description = "Domain name for Kanidm authentication service"
  default     = "auth.example.com"
}

# JuiceFS Configuration
variable "juicefs_bucket_name" {
  type        = string
  description = "OCI Object Storage bucket name for JuiceFS"
  default     = "juicefs-storage"
}

# Passwords are automatically generated using random_password resources

# OCI namespace is automatically discovered via data source

variable "object_storage_private_endpoint" {
  type        = string
  description = "Private endpoint URL for Object Storage (created manually)"
  default     = ""
}

# Grafana OAuth2 Configuration
variable "grafana_oauth_client_secret" {
  type        = string
  description = "OAuth2 client secret for Grafana authentication with Kanidm"
  sensitive   = true
  default     = "change-me-after-kanidm-setup"
}

# OAuth2 Proxy Configuration for JuiceFS
variable "oauth2_proxy_client_id" {
  type        = string
  description = "OAuth2 client ID for oauth2-proxy authentication with Kanidm"
  default     = "juicefs-proxy"
}

variable "oauth2_proxy_client_secret" {
  type        = string
  description = "OAuth2 client secret for oauth2-proxy authentication with Kanidm"
  sensitive   = true
  default     = "change-me-after-kanidm-setup"
}

# Docker Hub Registry Credentials
variable "docker_hub_username" {
  type        = string
  description = "Docker Hub username for image pull secrets"
  sensitive   = true
  default     = ""
}

variable "docker_hub_password" {
  type        = string
  description = "Docker Hub password or access token for image pull secrets"
  sensitive   = true
  default     = ""
}

variable "docker_hub_email" {
  type        = string
  description = "Docker Hub email address"
  sensitive   = true
  default     = ""
}
