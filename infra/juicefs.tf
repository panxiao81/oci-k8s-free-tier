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
            bucket       = var.object_storage_private_endpoint == "" ? "https://${data.oci_objectstorage_namespace.juicefs_namespace.namespace}.compat.objectstorage.${var.region}.oraclecloud.com/${var.juicefs_bucket_name}" : "${var.object_storage_private_endpoint}/${var.juicefs_bucket_name}"
            accessKey    = oci_identity_customer_secret_key.juicefs_secret_key.id
            secretKey    = oci_identity_customer_secret_key.juicefs_secret_key.key
          }
          reclaimPolicy = "Delete"
          allowVolumeExpansion = true
          # Mount pod resource optimization for free tier
          mountPod = {
            resources = {
              limits = {
                cpu    = "500m"
                memory = "1Gi"
              }
              requests = {
                cpu    = "100m"
                memory = "512Mi"
              }
            }
          }
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
      globalConfig = {
        enabled = true
        manageByHelm = true
        mountPodPatch = [
          {
            resources = {
              requests = {
                cpu = "100m"
                memory = "512Mi"
              }
              limits = {
                cpu = "500m"
                memory = "1Gi"
              }
            }
          }
        ]
      }
      dashboard = {
        ingress = {
          enabled = true
          hosts = [{
            host = "juicefs.${var.admin_subdomain}.${var.base_domain}"
            paths = [{
              path = "/"
              pathType = "ImplementationSpecific"
            }]
  }]
          className = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
            "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
            # External authentication via oauth2-proxy
            "nginx.ingress.kubernetes.io/auth-url" = "https://juicefs.${var.admin_subdomain}.${var.base_domain}/oauth2/auth"
            "nginx.ingress.kubernetes.io/auth-signin" = "https://juicefs.${var.admin_subdomain}.${var.base_domain}/oauth2/start?rd=$escaped_request_uri"
          }
          tls = [{
            secretName = "juicefs-dashboard-tls"
            hosts = ["juicefs.${var.admin_subdomain}.${var.base_domain}"]
          }]
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
