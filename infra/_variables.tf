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
