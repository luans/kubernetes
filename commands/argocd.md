# ArgoCD

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes.

## Getting the Default Admin Password

On a fresh ArgoCD installation, the initial admin password is auto-generated and stored in a Kubernetes secret.

### Retrieve the password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Login via CLI

```bash
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
```

## Accessing the ArgoCD UI

### Port Forward to the ArgoCD Server

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: `https://localhost:8080`

> [!NOTE]
> Default credentials: **Username:** `admin` | **Password:** retrieved from the command above.

## Changing the Admin Password

After logging in, it's recommended to change the default password:

### Via CLI

```bash
argocd account update-password
```

### Via UI

1. Go to **User Info** (left sidebar)
2. Click **Update Password**
3. Enter the current and new password

## Useful Commands

| Command | Description |
|---------|-------------|
| `argocd app list` | List all applications |
| `argocd app sync <app-name>` | Manually sync an application |
| `argocd app get <app-name>` | Get application details |
| `argocd app delete <app-name>` | Delete an application |
| `argocd cluster list` | List registered clusters |

> After changing the password, delete the initial secret for security:
>
> ```bash
> kubectl -n argocd delete secret argocd-initial-admin-secret
> ```

## Google Integration for Authentication

Create the following ConfigMap to enable Google authentication:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.my-domain.com.br
  admin.enabled: "false"
  login.delegation.enabled: "true"
  dex.config: |
    connectors:
      - type: google
        id: google
        name: Google
        config:
          issuer: https://accounts.google.com
          clientID: my-client-id
          clientSecret: my-client-secret
          scopes:
            - profile
            - email
          hostedDomains:
            - restricted-to-my-domain.com.br

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  scopes: '[email, groups]'
  policy.csv: |
    g, myemail@gmail.com.br, role:admin

```

If you disable admin login using `admin.enabled: "false"` and `login.delegation.enabled: "true"`, the login screen will show only Google as the authentication method.
