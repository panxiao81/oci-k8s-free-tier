# Create databases and users using Kubernetes Job (since MySQL is in private subnet)
resource "kubernetes_job" "mysql_init" {
  metadata {
    name      = "mysql-init"
    namespace = "default"
  }

  spec {
    template {
      metadata {
        labels = {
          job = "mysql-init"
        }
      }

      spec {
        restart_policy = "Never"
        image_pull_secrets {
          name = "docker-hub"  # Ensure you have a secret for Docker Hub credentials if needed
        }
        container {
          name  = "mysql-init"
          image = "mysql:8.0"
          image_pull_policy = "IfNotPresent"

          command = [
            "/bin/bash",
            "-c",
            <<-EOF
            # Wait for MySQL to be ready
            until mysql -h ${oci_mysql_mysql_db_system.shared_mysql.ip_address} -u admin -p$MYSQL_ADMIN_PASSWORD -e "SELECT 1;" > /dev/null 2>&1; do
              echo "Waiting for MySQL to be ready..."
              sleep 5
            done

            echo "MySQL is ready, creating databases and users..."

            mysql -h ${oci_mysql_mysql_db_system.shared_mysql.ip_address} -u admin -p$MYSQL_ADMIN_PASSWORD <<MYSQL_SCRIPT
            -- Create databases
            CREATE DATABASE IF NOT EXISTS juicefs;
            
            -- Create JuiceFS user
            CREATE USER IF NOT EXISTS 'juicefs'@'%' IDENTIFIED BY '$JUICEFS_PASSWORD';
            GRANT ALL PRIVILEGES ON juicefs.* TO 'juicefs'@'%';
            
            FLUSH PRIVILEGES;
            MYSQL_SCRIPT

            echo "Database initialization completed successfully!"
            EOF
          ]

          env {
            name  = "MYSQL_ADMIN_PASSWORD"
            value = random_password.mysql_admin_password.result
          }

          env {
            name  = "JUICEFS_PASSWORD"
            value = random_password.juicefs_mysql_password.result
          }

        }
      }
    }
  }

  depends_on = [oci_mysql_mysql_db_system.shared_mysql]
}