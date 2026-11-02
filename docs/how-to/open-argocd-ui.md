# Open the Argo CD UI

This guide shows how to open the Argo CD UI of an instance from your computer.

## Prerequisites

- The instance is up, for example after `mise run instance:up kind-local`.
- Your kubectl context points to the instance. For a Kind instance, `instance:up` sets the context `kind-<cluster>`.

## Open the UI

1. Get the initial password of the `admin` user:

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d; echo
   ```

2. Forward a local port to the Argo CD server:

   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:80
   ```

   Keep this command running.

3. Open <http://localhost:8080> in a browser.
4. Log in as `admin` with the password from step 1.

The server does not use TLS (`server.insecure: true`). The port-forward tunnel encrypts the traffic between your computer and the cluster.

## Examine the Applications with kubectl

```bash
kubectl -n argocd get applications
```

The `argocd` Application must show `Synced` and `Healthy`. Each component of `gitops/clusters/<cluster>/cluster.yaml` has one Application with the same name.

## Related pages

- [Force a sync](force-a-sync.md)
- [GitOps layout](../reference/gitops-layout.md#argo-cd-settings): the settings of the server and of the roles.
- [GitOps with Argo CD](../explanation/gitops-with-argocd.md)
