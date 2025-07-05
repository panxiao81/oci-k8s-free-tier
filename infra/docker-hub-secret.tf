# Docker Hub Image Pull Secret
# Creates a secret for pulling images from Docker Hub to avoid rate limiting

# Create Docker Hub registry secret for default namespace
resource "kubernetes_secret" "docker_hub" {
  metadata {
    name      = "docker-hub"
    namespace = "default"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = { 
        "https://index.docker.io/v1/" = {
          username = var.docker_hub_username
          password = var.docker_hub_password
          email    = var.docker_hub_email
          auth     = base64encode("${var.docker_hub_username}:${var.docker_hub_password}")
        }
      }
    })
  }
}
