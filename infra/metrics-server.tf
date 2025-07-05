# Metrics Server for resource monitoring
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  create_namespace = false
  version          = "3.12.2"

  values = [
    yamlencode({
      # Custom args including OCI-specific settings
      args = [
        "--kubelet-insecure-tls",  # Required for self-signed kubelet certificates in OCI
        "--secure-port=4443"       # Custom secure port
      ]
      
      # Custom container port to match secure-port
      containerPort = 4443
      
      # Resource configuration suitable for free tier
      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }

      # Tolerations for system components
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        },
        {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        },
        {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]

      # API service configuration
      apiService = {
        create = true
        insecureSkipTLSVerify = true
      }
    })
  ]
}