# CORS with Kubernetes Gateway API + Istio

> Troubleshooting guide for CORS issues in a Kubernetes environment using Gateway API (Istio) with HTTPRoute.

---

## Context

Stack used:

- **Kubernetes Gateway API v1** (`gateway.networking.k8s.io/v1`)
- **Istio** as `gatewayClassName`
- **HTTPRoute** for service routing
- **Express (Node.js) backend** with CORS configured internally

---

## Problem

When accessing the API from the browser, requests were failing with a CORS error:

```
Access to XMLHttpRequest at 'https://api.mydomain.com.br/my-app/api/portal/portal-projects'
from origin 'https://my-app.mydomain.com.br' has been blocked by CORS policy.
```

---

## Diagnosis

### 1. Preflight OPTIONS returning 403

The browser sends an `OPTIONS` request before any authenticated request (preflight). This request was reaching the backend without a token and being blocked by the authentication layer with **403 Forbidden**.

### 2. Duplicated CORS headers

When trying to fix this by adding a `ResponseHeaderModifier` to the `HTTPRoute`, the CORS headers ended up duplicated:

```
access-control-allow-origin: https://my-app.mydomain.com.br,https://my-app.mydomain.com.br
access-control-allow-methods: GET,POST,PUT,DELETE,OPTIONS,PATCH,GET, POST, PUT, DELETE, OPTIONS, PATCH
```

This happened because the Express backend **was already responding with CORS headers**, and the Gateway API filter was using `add` (which appends) instead of `set` (which overwrites). The browser rejects multiple values in the same CORS header.

### 3. `Access-Control-Allow-Origin: *` with `credentials: true`

In one of the attempts, the origin was set to `*` while `Access-Control-Allow-Credentials` was `true`. This is **invalid per the CORS spec** — the browser automatically rejects this combination.

---

## Solution

### Step 1 — Allow OPTIONS in Istio with `AuthorizationPolicy`

Create an `AuthorizationPolicy` that allows `OPTIONS` requests to pass through without authentication, **scoped only to the target service** via `selector`:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-options-preflight-my-app
  namespace: <your-namespace>
spec:
  selector:
    matchLabels:
      app: my-app-<environment>  # exact pod label — check with kubectl get pods --show-labels
  action: ALLOW
  rules:
  - to:
    - operation:
        methods: ["OPTIONS"]
```

> ⚠️ **Important:** The `selector.matchLabels` ensures the policy applies **only to the target service's pods**, avoiding unintended impact on other services in the gateway.

To find the correct pod label:

```bash
kubectl get pods -n <namespace> --show-labels | grep my-app
```

### Step 2 — Ensure CORS is properly configured in the backend

Since the backend (Express) already handles CORS internally, **there is no need to add CORS filters in the HTTPRoute**. The gateway should only route the request — the backend is responsible for responding with the correct headers.

Make sure the backend is configured with:

```javascript
// Express example
app.use(cors({
  origin: 'https://my-app.mydomain.com.br', // explicit origin, never * with credentials
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Authorization', 'Content-Type', 'Accept', 'X-Requested-With'],
  credentials: true,
  maxAge: 86400
}));
```

### Step 3 — Final HTTPRoute (no CORS filters)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-<environment>
  namespace: <namespace>
spec:
  parentRefs:
  - name: main-gateway
    namespace: istio-ingress
  hostnames:
  - "api.mydomain.com.br"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /my-app
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    backendRefs:
    - name: my-app-<environment>
      port: 80
```

---

## Common Pitfalls

| Problem | Cause | Fix |
|---|---|---|
| `403` on OPTIONS | Auth layer blocking preflight | `AuthorizationPolicy` allowing OPTIONS |
| Duplicated CORS headers | `add` in `ResponseHeaderModifier` + backend already returns CORS | Use `set` instead of `add`, or remove the Gateway filter entirely |
| CORS fails even with correct headers | `Allow-Origin: *` with `credentials: true` | Use an explicit origin: `https://your-frontend.com` |
| `AuthorizationPolicy` affecting other services | Policy without `selector` applied to the entire namespace | Always use `selector.matchLabels` to scope by service |

---

## Validation

Check if the preflight is responding correctly:

```bash
curl -v -X OPTIONS https://api.mydomain.com.br/my-app/api/portal/portal-projects \
  -H "Origin: https://my-app.mydomain.com.br" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: authorization"
```

Expected response:

- Status: `204 No Content`
- `access-control-allow-origin`: single, exact value matching the request origin
- `access-control-allow-credentials`: `true`
- `access-control-allow-methods`: list of accepted methods
- No duplicated values in any header

---

## References

- [Kubernetes Gateway API — HTTPRoute Filters](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPRouteFilter)
- [Istio AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
- [MDN — CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)
- [Fetch Spec — CORS Protocol](https://fetch.spec.whatwg.org/#http-cors-protocol)
