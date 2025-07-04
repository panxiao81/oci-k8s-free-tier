# OCI MySQL Database Service (Free Tier)
# This MySQL instance can be shared across multiple services
resource "oci_mysql_mysql_db_system" "shared_mysql" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  
  shape_name = "MySQL.Free"
  
  subnet_id = module.vcn.subnet_all_attributes.private_subnet.id
  
  admin_password = random_password.mysql_admin_password.result
  admin_username = "admin"
  
  data_storage_size_in_gb = 50
  
  display_name = "shared-mysql"
  description  = "Shared MySQL database for cluster services"
  
  is_highly_available = false
  
  port          = 3306
  port_x        = 33060
}

# Output MySQL connection details for other services
output "mysql_ip_address" {
  value       = oci_mysql_mysql_db_system.shared_mysql.ip_address
  description = "IP address of the shared MySQL database"
}

output "mysql_port" {
  value       = oci_mysql_mysql_db_system.shared_mysql.port
  description = "Port of the shared MySQL database"
}

output "mysql_connection_string" {
  value       = "mysql://admin:${random_password.mysql_admin_password.result}@${oci_mysql_mysql_db_system.shared_mysql.ip_address}:${oci_mysql_mysql_db_system.shared_mysql.port}"
  description = "MySQL connection string for services"
  sensitive   = true
}