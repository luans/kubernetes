# App of Apps Example

This project demonstrates the **App of Apps** pattern using ArgoCD to manage multiple applications and environments in Kubernetes as code.

## Directory Structure

| Directory | Description |
|-----------|-------------|
| **`app-of-apps`** | The "Master" Helm chart. It does not contain application code but generates ArgoCD `Application` resources for other apps based on its configuration. |
| **`bootstrap`** | usage manifests to "bootstrap" the cluster. Applying these tells ArgoCD to start managing the `app-of-apps` chart. |
| **`charts`** | The actual application Helm charts (e.g., `backend`, `keycloak`). |
| **`infra`** | Shared infrastructure components managed separately or as a base layer. |
| **`platform`** | Platform-wide configurations such as networking policies and security settings. |

## How It Works

1.  **Bootstrap**: administrator applies a manifest from the `bootstrap/` directory (e.g., `bootstrap-dev.yaml`).
2.  **Parent App**: This creates a "Parent" Application in ArgoCD that looks at the `app-of-apps` chart.
3.  **Child Apps**: The `app-of-apps` chart renders templates that create multiple "Child" Application resources.
    - It reads `applications` and `environments` from `app-of-apps/values.yaml`.
    - It generates an Application for each valid app-environment pair.
    - It handles environment-specific content via `values-<env>.yaml`.

## Automated Networking & Security

This implementation automatically provisions key networking components:

- **Istio Gateway**: A `Gateway` resource (`main-gateway`) is created in the `istio-ingress` namespace. It is configured to handle both HTTP (port 80) and HTTPS (port 443) traffic.
- **TLS Certificates**: A `Certificate` resource (`main-gateway-cert`) is automatically created using `cert-manager`. It requests a certificate from Let's Encrypt (via the `letsencrypt` ClusterIssuer) and stores it in the `mycompany-credential` secret, which the Gateway uses for TLS termination.

## Usage

### Prerequisites
- Kubernetes Cluster
- ArgoCD installed (default namespace: `argocd`)

### Deploying an Environment

To spin up the **Development** environment:

```bash
kubectl apply -f bootstrap/bootstrap-dev.yaml
```

This will:
1. Create the `app-of-apps-dev` application.
2. ArgoCD will sync `app-of-apps`, which generates applications like `backend-api-dev` and `keycloak-dev`.
3. ArgoCD will then sync those generated applications.

### Deploying Infrastructure

To deploy base infrastructure:

```bash
kubectl apply -f bootstrap/bootstrap-infra.yaml
```

## Adding a New Application

1.  **Create Chart**: Place your Helm chart in `charts/<your-app>`.
2.  **Register App**: Add the application to `app-of-apps/values.yaml`:

    ```yaml
    applications:
      - name: your-app-name
        path: helm-charts/app-of-apps-example/charts/your-app
    ```

3.  **Configure Environment**:
    - If needed, add environment specific values in `charts/<your-app>/values-<env>.yaml`.
    - Use `exclude` in `app-of-apps/values.yaml` if the app should not be deployed to certain environments.
