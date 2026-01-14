# Kubernetes Port Forward

The `kubectl port-forward` command allows you to access services inside the Kubernetes cluster directly from your local machine, without needing to expose the service externally.

## Basic Syntax

```bash
kubectl port-forward <type>/<name> <local-port>:<remote-port> [options]
```

## Usage Examples

### Port Forward to a Service

```bash
kubectl port-forward svc/backend-api 8080:80
```

Access at: `http://localhost:8080`

### Port Forward to a specific Pod

```bash
kubectl port-forward pod/backend-api-xxxxx-yyyyy 8080:80
```

### Port Forward with a specific namespace

```bash
kubectl port-forward svc/backend-api 8080:80 -n dev
```

### Port Forward in background

```bash
kubectl port-forward svc/backend-api 8080:80 &
```

## Useful Options

| Option | Description |
|--------|-------------|
| `-n, --namespace` | Specifies the resource namespace |
| `--address` | Addresses to listen on (default: localhost) |
| `--pod-running-timeout` | Timeout for waiting for the pod to be ready |

## Tips

> [!TIP]
> Use `Ctrl+C` to terminate the port-forward when running in foreground.

> [!NOTE]
> The port-forward remains active only while the command is running. For persistent access, consider using an Ingress or LoadBalancer.