# Open the Argo CD UI

This procedure opens the Argo CD UI of an instance from your computer.

## Prerequisites

- The instance is up, for example after `mise run instance:up kind-local`.
- Your kubectl context points to the instance. For a Kind instance, `instance:up` sets the context.

## Procedure

1. Get the initial password of the `admin` user:

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d; echo
   ```

2. Forward a local port to the Argo CD server:

   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:80
   ```

3. Open <http://localhost:8080> in a browser.
4. Log in as `admin` with the password from step 1.

The server does not use TLS (`server.insecure: true`). The port-forward tunnel and, later, the gateway give the encryption.

## Examine the Applications with kubectl

```bash
kubectl -n argocd get applicationsets,applications
```

The `argocd` Application must show `Synced` and `Healthy`.
