resource "kubernetes_namespace" "kanidm" {
  metadata {
    name = "kanidm"
    labels = {
      name = "kanidm"
    }
  }
}

resource "kubernetes_persistent_volume_claim" "kanidm_data" {
  metadata {
    name      = "kanidm-data"
    namespace = kubernetes_namespace.kanidm.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    storage_class_name = "juicefs-sc"
  }
  depends_on = [helm_release.juicefs_csi]
}

resource "kubernetes_config_map" "kanidm_config" {
  metadata {
    name      = "kanidm-config"
    namespace = kubernetes_namespace.kanidm.metadata[0].name
  }

  data = {
    "server.toml" = templatefile("${path.module}/kanidm-server.toml.tpl", {
      domain = var.kanidm_domain
      origin = "https://${var.kanidm_domain}"
    })
  }
}

resource "kubernetes_manifest" "kanidm_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "kanidm-tls"
      namespace = kubernetes_namespace.kanidm.metadata[0].name
    }
    spec = {
      secretName = "kanidm-tls"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = [
        var.kanidm_domain
      ]
    }
  }
}

resource "kubernetes_deployment" "kanidm" {
  metadata {
    name      = "kanidm"
    namespace = kubernetes_namespace.kanidm.metadata[0].name
    labels = {
      app = "kanidm"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "kanidm"
      }
    }

    template {
      metadata {
        labels = {
          app = "kanidm"
        }
      }

      spec {
        container {
          image = "kanidm/server:latest"
          name  = "kanidm"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8443
            name           = "https"
          }

          volume_mount {
            name       = "kanidm-data"
            mount_path = "/data"
          }

          volume_mount {
            name       = "kanidm-config"
            mount_path = "/data/server.toml"
            sub_path   = "server.toml"
          }

          volume_mount {
            name       = "kanidm-tls"
            mount_path = "/data/tls"
            read_only  = true
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/status"
              port = 8443
              scheme = "HTTPS"
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/status"
              port = 8443
              scheme = "HTTPS"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          env {
            name  = "KANIDM_CONFIG"
            value = "/data/server.toml"
          }
        }

        volume {
          name = "kanidm-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.kanidm_data.metadata[0].name
          }
        }

        volume {
          name = "kanidm-config"
          config_map {
            name = kubernetes_config_map.kanidm_config.metadata[0].name
          }
        }

        volume {
          name = "kanidm-tls"
          secret {
            secret_name = "kanidm-tls"
          }
        }

        image_pull_secrets {
          name = "docker-hub"
        }

        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }
      }
    }
  }
}

resource "kubernetes_service" "kanidm" {
  metadata {
    name      = "kanidm"
    namespace = kubernetes_namespace.kanidm.metadata[0].name
    labels = {
      app = "kanidm"
    }
  }

  spec {
    selector = {
      app = "kanidm"
    }

    port {
      name        = "https"
      port        = 443
      target_port = 8443
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "kanidm" {
  metadata {
    name      = "kanidm"
    namespace = kubernetes_namespace.kanidm.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-passthrough" = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.kanidm_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.kanidm.metadata[0].name
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
}