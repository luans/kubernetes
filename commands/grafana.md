# Grafana

Grafana tips and useful commands.

## Useful examples

### Port Forward to Grafana service installed using Helm

```bash
➜ kubectl port-forward svc/prometheus-stack-grafana 8080:80 -n monitoring
```

### Get default admin password

```bash
➜ kubectl get secrets/prometheus-stack-grafana -n monitoring -o json | jq '.data | map_values(@base64d)'
{
  "admin-password": "xxxxxx",
  "admin-user": "admin",
  "ldap-toml": ""
}
```
