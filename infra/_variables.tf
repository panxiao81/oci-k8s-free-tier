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
