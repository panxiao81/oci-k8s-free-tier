# OAuth2 Proxy for JuiceFS Dashboard Authentication
# Uses Helm chart for clean deployment and configuration
# Deployed in the same namespace as JuiceFS for logical grouping

# Generate random cookie secret for oauth2-proxy
resource "random_password" "oauth2_proxy_cookie_secret" {
  length  = 32
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Create secret for oauth2-proxy client credentials
resource "kubernetes_secret" "oauth2_proxy_credentials" {
  metadata {
    name      = "oauth2-proxy-credentials"
    namespace = kubernetes_namespace.juicefs.metadata[0].name
  }

  type = "Opaque"

  data = {
    client-id     = var.oauth2_proxy_client_id
    client-secret = var.oauth2_proxy_client_secret
    cookie-secret = random_password.oauth2_proxy_cookie_secret.result
  }
}

# Deploy oauth2-proxy using Helm chart
resource "helm_release" "oauth2_proxy" {
  name       = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.12.18"
  namespace  = kubernetes_namespace.juicefs.metadata[0].name

  values = [
    yamlencode({
      config = {
        # Use existing secret for credentials
        existingSecret = kubernetes_secret.oauth2_proxy_credentials.metadata[0].name
        clientID       = var.oauth2_proxy_client_id
        # Configure for OIDC provider (Kanidm)
        configFile = <<-EOT
          provider = "oidc"
          provider_display_name = "Kanidm"
          oidc_issuer_url = "https://${var.kanidm_domain}/oauth2/openid/${var.oauth2_proxy_client_id}"
          email_domains = [ "*" ]
          upstreams = [ "file:///dev/null" ]
          cookie_secure = true
          cookie_httponly = true
          cookie_samesite = "lax"
          skip_provider_button = true
          pass_basic_auth = false
          pass_access_token = false
          pass_user_headers = true
          set_xauthrequest = true
          allowed_groups = [ "infra_admin@${var.kanidm_domain}" ]
          redirect_url = "https://juicefs.${var.admin_subdomain}.${var.base_domain}/oauth2/callback"
          cookie_domains = [ "juicefs.${var.admin_subdomain}.${var.base_domain}" ]
          whitelist_domains = [ "juicefs.${var.admin_subdomain}.${var.base_domain}" ]
        EOT
      }

      # Service configuration
      service = {
        type       = "ClusterIP"
        portNumber = 4180
      }

      # Resource limits
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      # Ingress for OAuth2 authentication endpoints
      ingress = {
        enabled   = true
        className = "nginx"
        path      = "/oauth2"
        pathType  = "Prefix"
        hosts = [
          "juicefs.${var.admin_subdomain}.${var.base_domain}"
        ]
        annotations = {
          "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
          "cert-manager.io/cluster-issuer"           = "letsencrypt-prod"
        }
        tls = [
          {
            secretName = "juicefs-dashboard-tls"
            hosts = [
              "juicefs.${var.admin_subdomain}.${var.base_domain}"
            ]
          }
        ]
      }

      # Security settings
      securityContext = {
        enabled = true
        runAsNonRoot = true
        runAsUser = 2000
        runAsGroup = 2000
      }

      # Add imagePullSecrets for Docker Hub rate limiting
      imagePullSecrets = [
        { name = "docker-hub" }
      ]

      # Disable redis for simple cookie-based sessions
      redis = {
        enabled = false
      }

      # Session storage using cookies (simpler for small deployments)
      sessionStorage = {
        type = "cookie"
      }

      # Enable metrics for monitoring
      metrics = {
        enabled = true
        port = 44180
      }
    })
  ]

  depends_on = [
    kubernetes_secret.oauth2_proxy_credentials,
    helm_release.nginx_ingress,
    helm_release.cert_manager
  ]
}