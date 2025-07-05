# VictoriaMetrics + VictoriaLogs + Grafana Observability Stack

# VictoriaMetrics for metrics storage
resource "helm_release" "victoriametrics" {
  name             = "victoriametrics"
  repository       = "https://victoriametrics.github.io/helm-charts"
  chart            = "victoria-metrics-single"
  namespace        = "observability"
  create_namespace = true
  version          = "0.22.0"

  values = [
    yamlencode({
      server = {
        persistentVolume = {
          enabled = true
          size    = "2Gi"
          storageClassName = "juicefs-sc"
        }
        
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
        
        retentionPeriod = "7d"
        
        service = {
          type = "ClusterIP"
          servicePort = 8428
        }
        
        extraArgs = {
          "http.maxGracefulShutdownDuration" = "30s"
          "search.maxConcurrentRequests"     = "8"
          "search.maxQueryDuration"          = "30s"
        }
      }
    })
  ]
}

# VictoriaLogs for log storage
resource "helm_release" "victorialogs" {
  name             = "victorialogs"
  repository       = "https://victoriametrics.github.io/helm-charts"
  chart            = "victoria-logs-single"
  namespace        = "observability"
  create_namespace = true
  version          = "0.11.3"

  values = [
    yamlencode({
      server = {
        persistentVolume = {
          enabled = true
          size    = "2Gi"
          storageClassName = "juicefs-sc"
        }
        
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
        
        retentionPeriod = "3d"
        
        service = {
          type = "ClusterIP"
          servicePort = 9428
        }
        
        extraArgs = {
          "http.maxGracefulShutdownDuration" = "30s"
          "logNewStreams"                   = "true"
        }
      }
    })
  ]
}

# Grafana admin credentials secret
resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana"
    namespace = "observability"
  }

  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_admin_password.result
  }

  type = "Opaque"
}

# OAuth2 client secret for Grafana
# IMPORTANT: You need to configure the OAuth2 client in Kanidm manually after deployment:
# 1. Login to Kanidm as admin
# 2. Create OAuth2 application with client_id "grafana"
# 3. Set redirect URI to "https://grafana.admin.yourdomain.com/login/generic_oauth"
# 4. Update the client_secret below with the generated secret from Kanidm
resource "kubernetes_secret" "grafana_oauth" {
  metadata {
    name      = "grafana-oauth"
    namespace = "observability"
  }

  data = {
    client_secret = var.grafana_oauth_client_secret
  }

  type = "Opaque"
}

# Grafana for visualization
resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = "observability"
  create_namespace = true
  version          = "9.2.9"

  values = [
    yamlencode({
      persistence = {
        enabled = true
        size    = "1Gi"
        storageClassName = "juicefs-sc"
      }
      
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
      
      service = {
        type = "ClusterIP"
        port = 80
      }
      
      # Environment variables
      env = {
        GF_SECURITY_ADMIN_PASSWORD = random_password.grafana_admin_password.result
      }
      
      # Mount OAuth2 secret
      extraSecretMounts = [
        {
          name = "grafana-oauth"
          secretName = "grafana-oauth"
          defaultMode = 256
          mountPath = "/etc/secrets/grafana-oauth"
          readOnly = true
        }
      ]
      
      ingress = {
        enabled = true
        ingressClassName = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        path = "/"
        pathType = "Prefix"
        hosts = [
          "grafana.${var.admin_subdomain}.${var.base_domain}"
        ]
        tls = [
          {
            secretName = "grafana-tls"
            hosts = ["grafana.${var.admin_subdomain}.${var.base_domain}"]
          }
        ]
      }
      
      # Pre-configure VictoriaMetrics and VictoriaLogs as data sources
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "VictoriaMetrics"
              type      = "prometheus"
              url       = "http://victoriametrics-victoria-metrics-single-server:8428"
              access    = "proxy"
              isDefault = true
            },
            {
              name   = "VictoriaLogs"
              type   = "loki"
              url    = "http://victorialogs-victoria-logs-single-server:9428"
              access = "proxy"
              jsonData = {
                maxLines = 1000
              }
            }
          ]
        }
      }
      
      # Basic dashboards configuration
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }
          ]
        }
      }
      
      # Pre-load some basic dashboards
      dashboards = {
        default = {
          "kubernetes-cluster-monitoring" = {
            gnetId     = 7249
            revision   = 1
            datasource = "VictoriaMetrics"
          }
          "kubernetes-pod-monitoring" = {
            gnetId     = 6417
            revision   = 1
            datasource = "VictoriaMetrics"
          }
        }
      }
      
      # Grafana configuration with OAuth2
      "grafana.ini" = {
        server = {
          root_url = "https://grafana.${var.admin_subdomain}.${var.base_domain}"
        }
        security = {
          admin_user     = "admin"
          admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}"
        }
        users = {
          allow_sign_up = false
          auto_assign_org = true
          auto_assign_org_role = "Viewer"
        }
        auth = {
          disable_login_form = false  # Keep form as fallback
        }
        "auth.generic_oauth" = {
          enabled = true
          name = "Kanidm"
          client_id = "grafana"
          client_secret = "$__file{/etc/secrets/grafana-oauth/client_secret}"
          scopes = "openid profile email groups"
          auth_url = "https://${var.kanidm_domain}/ui/oauth2"
          token_url = "https://${var.kanidm_domain}/oauth2/token"
          api_url = "https://${var.kanidm_domain}/oauth2/openid/grafana/userinfo"
          login_attribute_path = "preferred_username"
          groups_attribute_path = "groups"
          name_attribute_path = "name"
          email_attribute_path = "email"
          role_attribute_path = "groups"
          allow_assign_grafana_admin = true
          skip_org_role_sync = false
        }
      }
    })
  ]
  
  depends_on = [kubernetes_secret.grafana_admin, kubernetes_secret.grafana_oauth]
}