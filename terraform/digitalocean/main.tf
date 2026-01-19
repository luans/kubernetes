## New K8s Cluster
resource "digitalocean_kubernetes_cluster" "kubernetes-doks-development" {
  name    = "kubernetes-doks-development"
  region  = "nyc1"
  version = "1.32.10-do.2"

  node_pool {
    name       = "k8s-pool"
    size       = "s-4vcpu-8gb"
    node_count = 1
  }
}

## New namespace for monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [digitalocean_kubernetes_cluster.kubernetes-doks-development]
}

## Istio Base (CRDs)
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = "istio-system"
  create_namespace = true

  atomic = true
}

## Istiod (Control Plane)
resource "helm_release" "istiod" {
  name             = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  namespace        = "istio-system"
  create_namespace = true
  atomic           = true

  depends_on = [helm_release.istio_base]

  set = [
    {
      name  = "pilot.env.PILOT_ENABLE_GATEWAY_API"
      value = "true"
    }
  ]
}

## Istio Ingress Gateway
resource "helm_release" "istio_ingress" {
  name             = "istio-ingress"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  namespace        = "istio-ingress"
  create_namespace = true
  atomic           = true

  # Depende do Control Plane
  depends_on = [helm_release.istiod]

  # Configuração explícita das portas (NodePort)
  values = [
    <<EOF
service:
  type: NodePort
  selector:
    istio: ingress
  ports:
  - name: status-port
    port: 15021
    targetPort: 15021
    nodePort: 30021   # Porta de status/healthcheck do Istio
    protocol: TCP
  - name: http2
    port: 80
    targetPort: 80
    nodePort: 30080   # Porta HTTP fixa
    protocol: TCP
  - name: https
    port: 443
    targetPort: 443
    nodePort: 30443   # Porta HTTPS fixa
    protocol: TCP
EOF
  ]
}

## Prometheus Community
resource "helm_release" "prometheus_stack" {
  name       = "prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  atomic     = true

  values = [
    <<EOF
grafana:
  additionalDataSources:
    - name: Loki
      type: loki
      url: http://loki.monitoring.svc.cluster.local:3100
      access: proxy
    - name: Tempo
      type: tempo
      url: http://tempo.monitoring.svc.cluster.local:3100
      access: proxy
      jsonData:
        httpMethod: GET
        tracesToLogs:
          datasourceUid: 'Loki'
          tags: ['job', 'instance', 'pod', 'namespace']
          mappedTags: [{ key: 'service.name', value: 'service' }]
          mapTagNamesEnabled: false
          spanStartTimeShift: '1h'
          spanEndTimeShift: '1h'
          filterByTraceID: false
          filterBySpanID: false
EOF
  ]

  depends_on = [
    helm_release.loki,
    helm_release.tempo
  ]
}

## Loki
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = "monitoring"
  atomic     = true

  set = [
    {
      name  = "promtail.enabled"
      value = "true"
    }
  ]
}

## Tempo
resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = "monitoring"
  atomic     = true
}

## ArgoCD
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  atomic           = true
  timeout          = 600
}

## External load balancer (Managed by Terraform)
resource "digitalocean_loadbalancer" "public_lb" {
  name   = "kubernetes-lb-development"
  region = "nyc1"

  droplet_tag = "k8s:${digitalocean_kubernetes_cluster.kubernetes-doks-development.id}"

  forwarding_rule {
    entry_port      = 80
    entry_protocol  = "tcp"
    target_port     = 30080
    target_protocol = "tcp"
  }

  forwarding_rule {
    entry_port      = 443
    entry_protocol  = "tcp"
    target_port     = 30443
    target_protocol = "tcp"
  }

  healthcheck {
    port                     = 30021
    protocol                 = "tcp"
    check_interval_seconds   = 10
    response_timeout_seconds = 5
    unhealthy_threshold      = 3
    healthy_threshold        = 3
  }
}

## Load balancer IP output
output "load_balancer_ip" {
  value       = digitalocean_loadbalancer.public_lb.ip
  description = "Aponte seu domínio (A Record) para este IP"
}


# Install cert-manager
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.13.3"

  set = [
    {
      name  = "installCRDs"
      value = "true"
    }
  ]
}
