mode: daemonset
image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib
  tag: '0.129.1'
presets:
  logsCollection:
    enabled: true
    includeCollectorLogs: false  # Reduce log volume
  hostMetrics:
    enabled: false  # Disable to reduce metrics volume
  kubernetesAttributes:
    enabled: true
  kubeletMetrics:
    enabled: true  # Keep essential Kubernetes metrics
  kubernetesEvents:
    enabled: false  # Disable events to reduce log volume

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: "0.0.0.0:4317"
        http:
          endpoint: "0.0.0.0:4318"
    prometheus:
      config:
        scrape_configs:
        - job_name: "kubernetes-pods"
          kubernetes_sd_configs:
          - role: pod
          relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
    k8s_cluster:
      auth_type: serviceAccount
      node_conditions_to_report: ["Ready", "MemoryPressure", "DiskPressure", "PIDPressure"]
      allocatable_types_to_report: ["cpu", "memory", "storage"]

  processors:
    batch: {}
    memory_limiter:
      limit_mib: 512
    
    # Filter out noisy logs to reduce storage usage
    filter/logs:
      error_mode: ignore
      logs:
        log_record:
        # Filter out debug and info level logs from system namespaces
        - 'IsMatch(attributes["k8s.namespace.name"], "kube-.*") and severity_number < SEVERITY_NUMBER_WARN'
        # Filter out health check logs
        - 'IsMatch(body, ".*health.*check.*") == true'
        # Filter out GET requests with 200 status
        - 'IsMatch(body, "GET.*200.*") == true'
    
    k8sattributes:
      auth_type: serviceAccount
      passthrough: false
      extract:
        metadata:
        - "k8s.pod.name"
        - "k8s.pod.uid"
        - "k8s.deployment.name"
        - "k8s.namespace.name"
        - "k8s.node.name"
        - "k8s.pod.start_time"
      pod_association:
      - sources:
        - from: resource_attribute
          name: "k8s.pod.ip"
      - sources:
        - from: resource_attribute
          name: "k8s.pod.uid"
      - sources:
        - from: connection

  exporters:
    debug:
      verbosity: basic
    
    # Export metrics to VictoriaMetrics using remote write
    prometheusremotewrite:
      endpoint: "http://victoriametrics-victoria-metrics-single-server.observability.svc.cluster.local:8428/api/v1/write"
      tls:
        insecure: true
      resource_to_telemetry_conversion:
        enabled: true
    
    # Export logs to VictoriaLogs using native OTLP
    otlphttp/victorialogs:
      logs_endpoint: "http://victorialogs-victoria-logs-single-server.observability.svc.cluster.local:9428/insert/opentelemetry/v1/logs"
      headers:
        VL-Stream-Fields: "k8s.namespace.name,k8s.pod.name,k8s.container.name,k8s.node.name"

  service:
    pipelines:
      traces:
        receivers: ["otlp"]
        processors: ["memory_limiter", "k8sattributes", "batch"]
        exporters: ["debug"]
      metrics:
        receivers: ["otlp", "prometheus", "k8s_cluster"]
        processors: ["memory_limiter", "k8sattributes", "batch"]
        exporters: ["prometheusremotewrite", "debug"]
      logs:
        receivers: ["otlp"]
        processors: ["memory_limiter", "filter/logs", "k8sattributes", "batch"]
        exporters: ["otlphttp/victorialogs", "debug"]

resources:
  limits:
    cpu: "256m"
    memory: "512Mi"
  requests:
    cpu: "100m"
    memory: "128Mi"

tolerations:
- key: "node-role.kubernetes.io/master"
  operator: "Exists"
  effect: "NoSchedule"
- key: "node-role.kubernetes.io/control-plane"
  operator: "Exists"
  effect: "NoSchedule"