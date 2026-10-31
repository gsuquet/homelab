# Explanation: GitOps with ArgoCD

This document explains how GitOps is implemented in this homelab and the specific patterns ArgoCD uses to manage the cluster.

---

## What GitOps Means

GitOps is a practice where Git is the single source of truth for the desired state of a system. Instead of running `kubectl apply` manually, you commit changes to Git and a controller (ArgoCD) reconciles the cluster to match.

The key properties:

- **Declarative**: The desired state is described in YAML files in Git, not in runbook steps
- **Versioned**: Every change is a Git commit with a message, author, and timestamp
- **Auditable**: `git log` shows exactly what changed and when
- **Self-healing**: If someone manually changes a resource in the cluster, ArgoCD reverts it on the next sync

---

## The new design: `gitops/`

The new design keeps all the GitOps sources in `gitops/`. It uses the layout of the Flux and Argo CD reference repositories: `clusters/`, `infrastructure/` and `apps/`. Argo CD manages itself from the first day. The `olympus` cluster still uses the old layout in `kubernetes/`, until its migration.

### Layout

| Folder | Content |
| --- | --- |
| `gitops/infrastructure/<component>/sources/` | A component that can change cluster-scoped resources, for example Argo CD or cert-manager. The chart and the values for all clusters. |
| `gitops/apps/<app>/sources/` | An application. The chart and the values for all clusters. |
| `gitops/clusters/<cluster>/` | All that is specific to one cluster: the list of components, the value overrides and the rendered manifests. |

A component is the same for each cluster. A cluster selects its components and can override their values. When two clusters need a different tool, for example two gateways, make two components and let each cluster select one. Do not make one component with values that change the tool.

A GitOps cluster and its Terraform instance have the same name: `instances/<name>/` creates the cluster, and `gitops/clusters/<name>/` tells Argo CD what to deploy on it. Terraform and GitOps stay in different folders, because Terraform runs one time and Argo CD reads Git all the time.

### Bootstrap

Terraform installs Argo CD one time. The `bootstrap-argocd` module applies the rendered manifests in `gitops/clusters/<cluster>/rendered/argocd/`. These manifests contain:

- Argo CD, rendered from the upstream `argo-cd` chart.
- The `infrastructure` and `apps` AppProjects.
- One Application for each component of the cluster, also for `argocd`.

Terraform applies only the `argocd` Application. This Application syncs the same rendered folder from Git. Thus, after the bootstrap, Argo CD manages itself, and it makes the other Applications in the order of their sync waves.

```text
Terraform (one time)              Git (main)
        │                             │
        ▼                             ▼
 rendered/argocd/  ─────────▶  argocd Application ──▶ Argo CD, AppProjects
                                      │
                                      ▼
                  one Application for each component in cluster.yaml,
                  in the order of the sync waves
```

Each `kubectl_manifest` in the module has `ignore_changes = all`. Terraform creates the resources, but it does not update them. Terraform applies them as the `argocd-controller` field manager, thus Argo CD owns all the fields after its first sync. Argo CD applies all the changes from Git, and Terraform and Argo CD do not fight over the same fields.

### Upgrade Argo CD

1. Change the chart version in `gitops/infrastructure/argocd/sources/Chart.yaml`, or change the values.
2. Run `mise run manifests:render`.
3. Merge the pull request.

The `argocd` Application syncs the new manifests and Argo CD upgrades itself.

### Entry point of a cluster

`gitops/clusters/<cluster>/cluster.yaml` lists the components and the applications of the cluster:

```yaml
apiVersion: infra.gsuquet.com/v1alpha1
kind: GitOpsCluster
name: kind-local
infrastructure:
  - name: argocd
    namespace: argocd
  - name: cert-manager
    namespace: cert-manager
apps:
  - name: home-assistant
    namespace: home-assistant
    dependsOn:
      - cert-manager
```

`mise run manifests:render` renders each listed component to `gitops/clusters/<cluster>/rendered/<component>/`. The `argocd` component renders one Application for each item ("app of apps"). Each Application syncs the rendered folder of its component.

To add a component, refer to [Add a GitOps component](../how-to/add-gitops-component.md).

### Values

A component renders with these values. A value in a later item replaces the same value in an earlier item.

1. `gitops/<group>/<component>/sources/values.yaml`: the values for all clusters.
2. `gitops.cluster`: the content of `cluster.yaml`. The `argocd` chart uses it to make the Applications.
3. `gitops/clusters/<cluster>/values/<component>.yaml`: the overrides for one cluster. This file is optional.

### Namespaces

Each component ships its own `Namespace` in `sources/templates/namespace.yaml`. Thus the Pod Security labels and the policy labels are in Git, and a reviewer sees them. The Applications do not use `CreateNamespace`. A Conftest policy makes sure that each `Namespace` in `gitops/` has the three Pod Security labels (`enforce`, `audit`, `warn`). `mise run schemas:check` makes sure that the rendered folder of each component contains the namespace of its item in `cluster.yaml`.

### Sync waves and dependencies

Argo CD applies the resources of one Application in waves. A Conftest policy checks the first two waves:

| Wave | Resources |
| --- | --- |
| `-2` | `Namespace` |
| `-1` | `CustomResourceDefinition` |
| `0` | All other resources (default) |
| `1` or more | Resources that need the custom resources of the same component, for example a `ClusterIssuer` after cert-manager |

Between components, `dependsOn` in `cluster.yaml` sets the order. The `argocd` chart gives each Application a sync wave: `1` without `dependsOn`, else the wave of its deepest dependency plus 1. The render fails when `dependsOn` names an unknown component or makes a cycle.

The Applications are resources of the `argocd` Application, thus the same waves order them. A health check in `argocd-cm` gives each Application the health of its resources. Thus Argo CD starts a wave only when the Applications of the previous waves are `Healthy`. A sync stops after 15 minutes (`controller.sync.timeout.seconds`), thus one component that is not `Healthy` does not stop all the later syncs.

The waves order the syncs of the `argocd` Application only: they apply when an Application is new or when its spec changes. When one commit changes the rendered manifests of two components, their two Applications sync at the same time. To upgrade a component and a component that needs it in a fixed order, use two pull requests.

`argocd` cannot have `dependsOn`: Argo CD syncs before all the other components. The `argocd` Application is in its own folder, thus the health check always makes it `Healthy`. Else it waits for itself.

### Argo CD settings

| Setting | Value | Reason |
| --- | --- | --- |
| Diff | Server-side (`controller.diff.server.side`) | It goes with server-side apply. Defaulted fields do not show as OutOfSync. |
| Default role | `role:readonly` | A logged-in user without a role can look, but not change. |
| Application health | Custom health check | The sync waves between components wait for each component. |
| Sync timeout | 15 minutes (`controller.sync.timeout.seconds`) | A component that is not `Healthy` does not stop the syncs of the `argocd` Application. |
| Resource exclusions | The chart defaults | They already exclude Endpoints, Leases, Cilium identities and endpoints, and Kyverno reports. |
| Resources | Memory request equal to the limit, a CPU request, no CPU limit | The cluster resource policy. Sized for a Raspberry Pi 4 with 8 GiB. |
| Admin user | On | Change the password and delete `argocd-initial-admin-secret` after the first login. SSO comes later. |

### Projects

| Project | Source | Cluster-scoped resources | Namespaces |
| --- | --- | --- | --- |
| `infrastructure` | This repository | All | All |
| `apps` | This repository | `Namespace` only | All, but not `kube-system` and `argocd` |

### Safety rules

- Argo CD does not prune the Argo CD CRDs. A deleted CRD deletes all the Applications.
- Argo CD does not prune or delete the `argocd` namespace, also when you delete the `argocd` Application.
- `mise run schemas:check` makes sure that each cluster lists `argocd`. Without it, the cluster has no `argocd` Application, and Argo CD does not manage itself. The `bootstrap-argocd` module also stops when the rendered folder has no `argocd` Application.
- All components use the rendered manifests pattern: `mise run schemas:check` makes sure that each folder in `gitops/infrastructure/` and `gitops/apps/` has `sources/Chart.yaml`.
- Each Application tries a failed sync again, up to 5 times. Argo CD does not try a failed sync again for the same revision without this setting.
- The Applications have no resources finalizer. When a component goes out of `cluster.yaml`, Argo CD deletes its Application, but the resources stay in the cluster. A Conftest policy denies the finalizer.
- The chart renders `argocd-secret` with no data. `argocd-server` does not start without this `Secret`. When it starts, it adds its keys, for example `server.secretkey`, and it makes `argocd-initial-admin-secret`.
- The annotation `Prune=false,Delete=false` on `argocd-secret` stops Argo CD from deleting the `Secret` when a commit removes it or when the Application is deleted. A Conftest policy denies a `Secret` with plain values in Git.

### Test a branch on Kind

The Applications sync `main`. To test a branch, add `gitops/clusters/kind-local/values/argocd.yaml` with `gitops.targetRevision` set to the branch name, and render. Remove the file before the merge. A Conftest policy fails `mise run lint` when a rendered Application does not sync `main`.

---

## Old layout: `kubernetes/` (olympus)

The rest of this page tells how the old layout works on `olympus`. The migration removes it.

### How ArgoCD Watches This Repository

ArgoCD is configured with a single Application called `argocd-bootstrap` (defined in `kubernetes/bootstrap/argo-cd/bootstrap-application.yaml`). This Application points at the `kubernetes/bootstrap/argo-cd/` directory in the repo:

```yaml
source:
  repoURL: https://github.com/gsuquet/homelab.git
  targetRevision: HEAD
  path: kubernetes/bootstrap/argo-cd
syncPolicy:
  automated:
    selfHeal: true
    prune: true
```

This Application manages ArgoCD itself — if you change any file in `kubernetes/bootstrap/argo-cd/`, ArgoCD detects the change and applies it to itself (a self-update).

---

### The ApplicationSet Pattern

Instead of writing an ArgoCD `Application` for every service, this project uses `ApplicationSet` resources that auto-discover applications by scanning Git directory paths.

#### Applications ApplicationSet

```yaml
# kubernetes/bootstrap/argo-cd/applications-applicationset.yaml
generators:
  - git:
      repoURL: https://github.com/gsuquet/homelab.git
      revision: HEAD
      directories:
        - path: kubernetes/applications/*
template:
  metadata:
    name: '{{.path.basename}}'
  spec:
    project: applications
    source:
      path: '{{.path}}'
    destination:
      namespace: '{{.path.basename}}'
    syncPolicy:
      automated:
        selfHeal: true
        prune: true
        serverSideApply: true
      syncOptions:
        - CreateNamespace=true
```

Every directory under `kubernetes/applications/` becomes an ArgoCD Application. The namespace is automatically created with the same name as the directory. No ArgoCD configuration needs to change when you add a new application — just create the directory and push.

The same pattern applies to `kubernetes/system/*` via the `system-applicationset.yaml`.

---

### Self-Managing ArgoCD

ArgoCD manages its own deployment. This is possible because ArgoCD is already running when it applies its own manifests — it effectively updates itself on the next sync.

The chain of self-management:

1. `bootstrap-application.yaml` — applied manually once by Ansible; makes ArgoCD watch `kubernetes/bootstrap/argo-cd/`
2. `applications-applicationset.yaml` and `system-applicationset.yaml` — managed by the bootstrap Application; auto-deploy all other apps
3. The rendered ArgoCD manifests in `manifests/` — managed by the bootstrap Application; ArgoCD applies updates to its own Deployments

If the ArgoCD version in `sources/Chart.yaml` is bumped, re-rendered, and pushed to Git, ArgoCD detects the change and performs a rolling update of its own pods.

---

### Sync Policy

All Applications and ApplicationSets in this project are configured with:

```yaml
syncPolicy:
  automated:
    selfHeal: true    # Revert manual changes to the cluster
    prune: true       # Delete resources removed from Git
  syncOptions:
    - ServerSideApply=true   # Use server-side apply (handles large CRDs better)
    - CreateNamespace=true   # Auto-create namespace if missing
```

- **`selfHeal: true`** means if you `kubectl edit` something in the cluster, ArgoCD reverts it within 3 minutes
- **`prune: true`** means if you delete a file from Git, ArgoCD deletes the corresponding resource from the cluster
- **`ServerSideApply`** avoids annotation size limits on large resources like CRDs

---

### How to Trigger a Sync

**Normal path**: Commit to the `main` branch and push. ArgoCD polls Git every 3 minutes and syncs automatically.

**Immediate sync** (without waiting 3 minutes):

```bash
# Trigger a refresh of a specific application
kubectl annotate application <app-name> -n argocd \
  argocd.argoproj.io/refresh=normal --overwrite

# Or hard refresh (clears cache)
kubectl annotate application <app-name> -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

**Manual sync via kubectl**:

```bash
kubectl patch application <app-name> -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

---

### ArgoCD Projects

Applications are grouped into two ArgoCD Projects, which define security boundaries:

| Project | Source Paths | Cluster Permissions | Namespace Restrictions |
| ------- | ------------ | ------------------- | ---------------------- |
| `system` | `kubernetes/` | All cluster-scoped resources | All namespaces |
| `applications` | `kubernetes/` | Namespace-scoped resources only | All except `kube-system` |

The `system` project needs cluster-scoped permissions to install CRDs and cluster roles (e.g., Sealed Secrets). The `applications` project intentionally restricts applications to their own namespaces.
