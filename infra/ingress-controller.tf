
# Manages the NGINX Ingress Controller using the Helm provider.
# This setup creates a single OCI Network Load Balancer (NLB) to handle both
# L7 (HTTP/S), L4 (TCP), and L4 (UDP) traffic.

resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0" # Pinning version for stable deployments

  values = [
    yamlencode({
      controller = {
        # This annotation is critical for OCI. It requests the free-tier Network Load Balancer.
        service = {
          type = "LoadBalancer"
          annotations = {
            "oci.oraclecloud.com/load-balancer-type" = "nlb"
          }
        }
        extraArgs = {
          enable-ssl-passthrough = "true" # Enables SSL passthrough for secure connections
        }
      }
      # This block instructs the Helm chart to create the required ConfigMap
      # for TCP services and expose the ports on the controller's service.
      # tcp: {}
      #   # Format: "<external-port>" = "<namespace>/<service-name>:<service-port>"
        
      #   # Example: Route traffic on port 3306 to a MySQL service
      #   "3306": "default/mysql-service:3306"

      #   # Example: Route traffic on port 5432 to a PostgreSQL service
      #   # "5432": "default/postgres-service:5432"

      # This block does the same for UDP services.
      # udp: {}
      #   # Format: "<external-port>" = "<namespace>/<service-name>:<service-port>"

      #   # Example: Route UDP traffic on port 5353 to a custom app
      #   "5353": "default/my-udp-app:5353"
    })
  ]
}

data "kubernetes_service" "ingress_controller_service" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.nginx_ingress]
}
