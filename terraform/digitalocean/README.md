# DigitalOcean Kubernetes Terraform Infrastructure

Terraform configuration for provisioning a fully-featured Kubernetes cluster on DigitalOcean with service mesh, observability, and GitOps capabilities.

## Overview

This Terraform project creates and manages:

| Component | Description |
|-----------|-------------|
| **DOKS Cluster** | DigitalOcean Managed Kubernetes (v1.32.10) |
| **Istio Service Mesh** | Complete Istio stack (Base, Istiod, Ingress Gateway) |
| **Observability Stack** | Prometheus, Grafana, Loki, and Tempo |
| **GitOps** | ArgoCD for continuous delivery |
| **Load Balancer** | DigitalOcean managed load balancer |

## File Structure

```text
digitalocean/
├── 📂 backend.tf   # Remote state configuration (DigitalOcean Spaces)
├── 📂 provider.tf  # Provider configurations (DO, Helm, Kubernetes)
├── 📂 main.tf      # Main infrastructure definitions
└── 📂 README.md    # This file
```

## Prerequisites

Before running this Terraform configuration, ensure you have:

1. **Terraform** >= 1.9.5 installed
2. **DigitalOcean API Token** with read/write permissions
3. **DigitalOcean Spaces credentials** (for remote state)
4. **doctl** CLI (optional, for cluster access)

## Environment Variables

Set the following environment variables before running Terraform:

```bash
# DigitalOcean API Token
export DIGITALOCEAN_TOKEN="your-do-api-token"

# For S3 Backend (DigitalOcean Spaces)
export AWS_ACCESS_KEY_ID="your-spaces-access-key"
export AWS_SECRET_ACCESS_KEY="your-spaces-secret-key"
```

> [!TIP]
> You can also use a `.env` file with [direnv](https://direnv.net/) for automatic environment loading.

## How to Execute

### 1. Initialize Terraform

Initialize the working directory and download required providers:

```bash
terraform init
```

### 2. Plan the Infrastructure

Preview the changes that Terraform will apply:

```bash
terraform plan
```

### 3. Apply the Configuration

Create/update the infrastructure:

```bash
terraform apply
```

> [!IMPORTANT]
> Review the plan output carefully before typing `yes` to confirm.

### 4. Get the Load Balancer IP

After successful apply, get the Load Balancer IP:

```bash
terraform output load_balancer_ip
```

Use this IP to configure your DNS A records.

## Destroying Infrastructure

To destroy all resources:

```bash
terraform destroy
```

> [!CAUTION]
> This will **permanently delete** the Kubernetes cluster and all associated resources. Make sure to backup any important data!

## Infrastructure Components

### Kubernetes Cluster

- **Name:** `kubernetes-doks-development`
- **Region:** NYC1 (New York)
- **Version:** 1.32.10-do.2
- **Node Pool:** 1 node (s-4vcpu-8gb)

### Istio Service Mesh

The Istio stack is deployed in the following order:

1. **Istio Base** - Custom Resource Definitions (CRDs)
2. **Istiod** - Control plane
3. **Istio Ingress Gateway** - Traffic routing (NodePort)

| Port | Service | NodePort |
|------|---------|----------|
| 15021 | Status/Healthcheck | 30021 |
| 80 | HTTP | 30080 |
| 443 | HTTPS | 30443 |

### Observability Stack

| Tool | Purpose | Namespace |
|------|---------|-----------|
| **Prometheus** | Metrics collection | monitoring |
| **Grafana** | Dashboards & visualization | monitoring |
| **Loki** | Log aggregation | monitoring |
| **Promtail** | Log shipping | monitoring |
| **Tempo** | Distributed tracing | monitoring |

> [!NOTE]
> Grafana is pre-configured with Loki and Tempo as additional data sources for unified observability.

### ArgoCD

- **Namespace:** argocd
- **Timeout:** 600s (accounts for large image pulls)

To access ArgoCD UI:

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then access: https://localhost:8080

### Load Balancer

The DigitalOcean Load Balancer is configured to:
- Forward port 80 → NodePort 30080 (HTTP)
- Forward port 443 → NodePort 30443 (HTTPS)
- Health check on port 30021 (Istio status port)

## Tips & Best Practices

### State Management

The state is stored remotely in DigitalOcean Spaces (S3-compatible):
- **Bucket:** `luans-terraform`
- **Key:** `workspace/development/terraform.tfstate`

> [!TIP]
> Consider enabling state locking with DynamoDB if working in a team.

### Connecting to the Cluster

After provisioning, configure kubectl access:

```bash
doctl kubernetes cluster kubeconfig save kubernetes-doks-development
```

### Scaling the Node Pool

To scale the node pool, modify `node_count` in `main.tf`:

```hcl
node_pool {
  name       = "k8s-pool"
  size       = "s-4vcpu-8gb"
  node_count = 3  # Change this value
}
```

Then apply the changes:

```bash
terraform apply -target=digitalocean_kubernetes_cluster.kubernetes-doks-development
```

### Accessing Grafana

```bash
# Get admin password
kubectl get secret -n monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Port forward
kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:80
```

Access: http://localhost:3000 (user: `admin`)

### Targeted Apply

To apply only specific resources (faster updates):

```bash
# Only the K8s cluster
terraform apply -target=digitalocean_kubernetes_cluster.kubernetes-doks-development

# Only ArgoCD
terraform apply -target=helm_release.argocd

# Only monitoring namespace
terraform apply -target=kubernetes_namespace.monitoring
```

### Troubleshooting

**Helm release stuck:**
```bash
terraform taint helm_release.argocd  # Forces recreation
terraform apply
```

**View detailed logs:**
```bash
TF_LOG=DEBUG terraform apply
```

**Reset state for a resource:**
```bash
terraform state rm helm_release.prometheus_stack
terraform apply
```

## Outputs

| Output | Description |
|--------|-------------|
| `load_balancer_ip` | Public IP of the Load Balancer (point your DNS here) |

## Useful Links

- [DigitalOcean Terraform Provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [Helm Terraform Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [Istio Documentation](https://istio.io/latest/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

---

> **Note:** Point your domain's A record to the Load Balancer IP output to route traffic to your cluster.
