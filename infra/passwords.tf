# Generate random passwords for database services
resource "random_password" "mysql_admin_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

resource "random_password" "juicefs_mysql_password" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true

  keepers = {
    version = "2"  # Change this to regenerate the password
  }
}

# Store passwords in Kubernetes secrets for easy access
resource "kubernetes_secret" "mysql_passwords" {
  metadata {
    name      = "mysql-passwords"
    namespace = "default"
  }

  data = {
    admin_password    = random_password.mysql_admin_password.result
    juicefs_password  = random_password.juicefs_mysql_password.result
  }

  type = "Opaque"
}

# Outputs for reference (passwords are sensitive)
output "mysql_admin_password" {
  value       = random_password.mysql_admin_password.result
  description = "Generated MySQL admin password"
  sensitive   = true
}

output "juicefs_mysql_password" {
  value       = random_password.juicefs_mysql_password.result
  description = "Generated JuiceFS MySQL password"
  sensitive   = true
}