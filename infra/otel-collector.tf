resource "helm_release" "opentelemetry_collector" {
  name             = "opentelemetry-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  namespace        = "observability"
  create_namespace = true
  version          = "0.127.2"

  values = [
    file("${path.module}/otel-config.yaml.tpl")
  ]
}