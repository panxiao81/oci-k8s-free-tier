# Get the ingress controller load balancer IP
data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.nginx_ingress]
}

# Create DNS A record for Kanidm
resource "cloudflare_record" "kanidm_dns" {
  zone_id = data.cloudflare_zone.main.id
  name    = split(".", var.kanidm_domain)[0]  # Extract subdomain (e.g., "auth" from "auth.ddupan.top")
  value   = data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].ip
  type    = "A"
  ttl     = 300
  proxied = false

  depends_on = [data.kubernetes_service.nginx_ingress_controller]
}

# Create DNS A record for JuiceFS Dashboard
resource "cloudflare_record" "juicefs_dashboard_dns" {
  zone_id = data.cloudflare_zone.main.id
  name    = "juicefs.${var.admin_subdomain}"
  value   = data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].ip
  type    = "A"
  ttl     = 300
  proxied = false

  depends_on = [data.kubernetes_service.nginx_ingress_controller]
}

# Create DNS A record for Grafana
resource "cloudflare_record" "grafana_dns" {
  zone_id = data.cloudflare_zone.main.id
  name    = "grafana.${var.admin_subdomain}"
  value   = data.kubernetes_service.nginx_ingress_controller.status[0].load_balancer[0].ingress[0].ip
  type    = "A"
  ttl     = 300
  proxied = false

  depends_on = [data.kubernetes_service.nginx_ingress_controller]
}

# Get the Cloudflare zone for base domain
data "cloudflare_zone" "main" {
  name = var.base_domain
}