resource "kubernetes_namespace" "juicefs" {
  metadata {
    name = "juicefs"
    labels = {
      name = "juicefs"
    }
  }
}

# JuiceFS uses the shared MySQL instance with its own database

# Kubernetes secret for JuiceFS credentials
resource "kubernetes_secret" "juicefs_credentials" {
  metadata {
    name      = "juicefs-credentials"
    namespace = kubernetes_namespace.juicefs.metadata[0].name
  }

  data = {
    access_key = oci_identity_customer_secret_key.juicefs_secret_key.id
    secret_key = oci_identity_customer_secret_key.juicefs_secret_key.key
  }

  type = "Opaque"
}

# JuiceFS CSI Driver
resource "helm_release" "juicefs_csi" {
  name             = "juicefs-csi-driver"
  repository       = "https://juicedata.github.io/charts/"
  chart            = "juicefs-csi-driver"
  namespace        = kubernetes_namespace.juicefs.metadata[0].name
  create_namespace = false
  version          = "0.28.4"

  values = [
    yamlencode({
      storageClasses = [
        {
          enabled = true
          name    = "juicefs-sc"
          backend = {
            name         = "oci-object-storage"
            metaurl      = "mysql://juicefs:${random_password.juicefs_mysql_password.result}@(${oci_mysql_mysql_db_system.shared_mysql.ip_address}:3306)/juicefs"
            storage      = "s3"
            bucket       = "https://${data.oci_objectstorage_namespace.juicefs_namespace.namespace}.compat.objectstorage.${var.region}.oraclecloud.com/${var.juicefs_bucket_name}"
            accessKey    = oci_identity_customer_secret_key.juicefs_secret_key.id
            secretKey    = oci_identity_customer_secret_key.juicefs_secret_key.key
          }
          reclaimPolicy = "Delete"
          allowVolumeExpansion = true
        }
      ]
      node = {
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
      }
      controller = {
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
      }
    })
  ]

  depends_on = [
    oci_mysql_mysql_db_system.shared_mysql,
    kubernetes_secret.juicefs_credentials,
    # kubernetes_job.juicefs_format
  ]
}

# JuiceFS Dashboard Service
resource "kubernetes_service" "juicefs_dashboard" {
  metadata {
    name      = "juicefs-dashboard"
    namespace = kubernetes_namespace.juicefs.metadata[0].name
    labels = {
      app = "juicefs-dashboard"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "juicefs-csi-driver"
    }
    port {
      name        = "dashboard"
      port        = 9567
      target_port = 9567
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }

  depends_on = [helm_release.juicefs_csi]
}

# JuiceFS Dashboard Ingress
resource "kubernetes_ingress_v1" "juicefs_dashboard" {
  metadata {
    name      = "juicefs-dashboard"
    namespace = kubernetes_namespace.juicefs.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-staging"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"
    
    tls {
      hosts      = ["juicefs.admin.ddupan.top"]
      secret_name = "juicefs-dashboard-tls"
    }

    rule {
      host = "juicefs.admin.ddupan.top"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.juicefs_dashboard.metadata[0].name
              port {
                number = 9567
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.juicefs_dashboard]
}

data "oci_objectstorage_namespace" "juicefs_namespace" {
  compartment_id = var.compartment_id
}