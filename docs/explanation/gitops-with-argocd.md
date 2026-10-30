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

The new design keeps all the GitOps sources in `gitops/`. Each instance has an entry point, and Argo CD manages itself from the first day. The `olympus` cluster still uses the old layout in `kubernetes/`, until its migration.

### Bootstrap

Terraform installs Argo CD one time. The `bootstrap-argocd` module applies the rendered manifests in `gitops/platform/argocd/rendered/<instance>/`. These manifests contain:

- Argo CD, rendered from the upstream `argo-cd` chart.
- The `platform` and `apps` AppProjects.
- The `platform` and `apps` ApplicationSets.

The `platform` ApplicationSet makes the `argocd` Application. This Application syncs the same rendered folder from Git. Thus, after the bootstrap, Argo CD manages itself.

```text
Terraform (one time)            Git (main)
        │                           │
        ▼                           ▼
 rendered/<instance>/  ──────▶  argocd Application ──▶ Argo CD, AppProjects, ApplicationSets
                                    │
          gitops/instances/<instance>.yaml
                                    │
                                    ▼
                    one Application for each component
```

Each `kubectl_manifest` in the module has `ignore_changes = all`. Terraform creates the resources, but it does not update them. Argo CD applies all the changes from Git. Thus Terraform and Argo CD do not fight over the same fields.

### Upgrade Argo CD

1. Change the chart version in `gitops/platform/argocd/sources/Chart.yaml`, or change the values.
2. Run `mise run manifests:render`.
3. Merge the pull request.

The `argocd` Application syncs the new manifests and Argo CD upgrades itself.

### Entry point of an instance

`gitops/instances/<instance>.yaml` lists the components and the applications of the instance. Each ApplicationSet uses a matrix generator: a Git file generator reads the entry point, and a list generator makes one item for each component. Each Application syncs `gitops/<group>/<name>/rendered/<instance>/`.

To add a component, refer to [Add a GitOps component](../how-to/add-gitops-component.md).

### Projects

| Project | Source | Cluster-scoped resources | Namespaces |
| --- | --- | --- | --- |
| `platform` | This repository | All | All |
| `apps` | This repository | `Namespace` only | All, but not `kube-system` and `argocd` |

### Safety rules

- Argo CD does not prune the `argocd` namespace and the Argo CD CRDs. A deleted CRD deletes all the Applications.
- The ApplicationSets have `preserveResourcesOnDeletion: true`. When a component goes out of the entry point, its resources stay in the cluster.
- The repository has no Argo CD `Secret`. Argo CD makes `argocd-secret` and `argocd-initial-admin-secret` when it starts.

### Test a branch on Kind

The ApplicationSets sync `main`. To test a branch, set `gitops.targetRevision` in `gitops/platform/argocd/values/kind-local.yaml` to the branch name, and render. Set it back to `main` before the merge. A Conftest policy fails `mise run lint` when a rendered ApplicationSet does not sync `main`.

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
