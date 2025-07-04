resource "helm_release" "opentelemetry_collector" {
  name             = "opentelemetry-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  namespace        = "observability"
  create_namespace = true
  version          = "0.127.2"

  values = [
    yamlencode({
      mode = "daemonset"
      
      image = {
        repository = "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-k8s"
        tag        = "0.129.1"
      }

      presets = {
        logsCollection = {
          enabled = true
          includeCollectorLogs = true
        }
        hostMetrics = {
          enabled = true
        }
        kubernetesAttributes = {
          enabled = true
        }
        kubeletMetrics = {
          enabled = true
        }
        kubernetesEvents = {
          enabled = true
        }
      }

      config = {
        receivers = {
          otlp = {
            protocols = {
              grpc = {
                endpoint = "0.0.0.0:4317"
              }
              http = {
                endpoint = "0.0.0.0:4318"
              }
            }
          }
          prometheus = {
            config = {
              scrape_configs = [
                {
                  job_name = "kubernetes-pods"
                  kubernetes_sd_configs = [
                    {
                      role = "pod"
                    }
                  ]
                  relabel_configs = [
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                      action = "keep"
                      regex = "true"
                    },
                    {
                      source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                      action = "replace"
                      target_label = "__metrics_path__"
                      regex = "(.+)"
                    },
                    {
                      source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                      action = "replace"
                      regex = "([^:]+)(?::\\d+)?;(\\d+)"
                      replacement = "$1:$2"
                      target_label = "__address__"
                    }
                  ]
                }
              ]
            }
          }
          k8s_cluster = {
            auth_type = "serviceAccount"
            node_conditions_to_report = ["Ready", "MemoryPressure", "DiskPressure", "PIDPressure"]
            allocatable_types_to_report = ["cpu", "memory", "storage"]
          }
        }

        processors = {
          batch = {}
          memory_limiter = {
            limit_mib = 512
          }
          k8sattributes = {
            auth_type = "serviceAccount"
            passthrough = false
            extract = {
              metadata = [
                "k8s.pod.name",
                "k8s.pod.uid",
                "k8s.deployment.name",
                "k8s.namespace.name",
                "k8s.node.name",
                "k8s.pod.start_time"
              ]
            }
            pod_association = [
              {
                sources = [
                  {
                    from = "resource_attribute"
                    name = "k8s.pod.ip"
                  }
                ]
              },
              {
                sources = [
                  {
                    from = "resource_attribute"
                    name = "k8s.pod.uid"
                  }
                ]
              },
              {
                sources = [
                  {
                    from = "connection"
                  }
                ]
              }
            ]
          }
        }

        exporters = {
          debug = {
            verbosity = "basic"
          }
          # Add your exporters here later
          # Example:
          # otlp = {
          #   endpoint = "http://your-backend:4317"
          #   tls = {
          #     insecure = true
          #   }
          # }
          # prometheus = {
          #   endpoint = "0.0.0.0:8889"
          # }
        }

        service = {
          pipelines = {
            traces = {
              receivers = ["otlp"]
              processors = ["memory_limiter", "k8sattributes", "batch"]
              exporters = ["debug"]
            }
            metrics = {
              receivers = ["otlp", "prometheus", "k8s_cluster"]
              processors = ["memory_limiter", "k8sattributes", "batch"]
              exporters = ["debug"]
            }
            logs = {
              receivers = ["otlp"]
              processors = ["memory_limiter", "k8sattributes", "batch"]
              exporters = ["debug"]
            }
          }
        }
      }

      resources = {
        limits = {
          cpu = "256m"
          memory = "512Mi"
        }
        requests = {
          cpu = "100m"
          memory = "128Mi"
        }
      }

      tolerations = [
        {
          key = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect = "NoSchedule"
        },
        {
          key = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect = "NoSchedule"
        }
      ]
    })
  ]
}