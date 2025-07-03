resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.15.1"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}

resource "kubernetes_secret" "cloudflare_api_token" {
  depends_on = [helm_release.cert_manager]
  metadata {
    name      = "cloudflare-api-token"
    namespace = "cert-manager"
  }

  data = {
    "api-token" = var.cloudflare_api_token
  }
}

resource "kubernetes_manifest" "letsencrypt_staging_issuer" {
  depends_on = [helm_release.cert_manager]
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-staging"
    }
    "spec" = {
      "acme" = {
        "email" = var.letsencrypt_email
        "server" = "https://acme-staging-v02.api.letsencrypt.org/directory"
        "privateKeySecretRef" = {
          "name" = "letsencrypt-staging"
        }
        "solvers" = [
          {
            "dns01" = {
              "cloudflare" = {
                "email" = var.letsencrypt_email
                "apiTokenSecretRef" = {
                  "name" = kubernetes_secret.cloudflare_api_token.metadata[0].name
                  "key"  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "letsencrypt_prod_issuer" {
  depends_on = [helm_release.cert_manager]
  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-prod"
    }
    "spec" = {
      "acme" = {
        "email" = var.letsencrypt_email
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "privateKeySecretRef" = {
          "name" = "letsencrypt-prod"
        }
        "solvers" = [
          {
            "dns01" = {
              "cloudflare" = {
                "email" = var.letsencrypt_email
                "apiTokenSecretRef" = {
                  "name" = kubernetes_secret.cloudflare_api_token.metadata[0].name
                  "key"  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }
}