terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.1"
    }
  }
}

provider "helm" {
  kubernetes = {
    host                   = digitalocean_kubernetes_cluster.kubernetes-doks-development.endpoint
    token                  = digitalocean_kubernetes_cluster.kubernetes-doks-development.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.kubernetes-doks-development.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.kubernetes-doks-development.endpoint
  token                  = digitalocean_kubernetes_cluster.kubernetes-doks-development.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.kubernetes-doks-development.kube_config[0].cluster_ca_certificate)
}
