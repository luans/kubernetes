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
