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

> [!TIP]
> After changing the password, delete the initial secret for security:
> ```bash
> kubectl -n argocd delete secret argocd-initial-admin-secret
> ```