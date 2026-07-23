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

## How ArgoCD Watches This Repository

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

## The ApplicationSet Pattern

Instead of writing an ArgoCD `Application` for every service, this project uses `ApplicationSet` resources that auto-discover applications by scanning Git directory paths.

### Applications ApplicationSet

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

## Self-Managing ArgoCD

ArgoCD manages its own deployment. This is possible because ArgoCD is already running when it applies its own manifests — it effectively updates itself on the next sync.

The chain of self-management:

1. `bootstrap-application.yaml` — applied manually once by Ansible; makes ArgoCD watch `kubernetes/bootstrap/argo-cd/`
2. `applications-applicationset.yaml` and `system-applicationset.yaml` — managed by the bootstrap Application; auto-deploy all other apps
3. The rendered ArgoCD manifests in `manifests/` — managed by the bootstrap Application; ArgoCD applies updates to its own Deployments

If the ArgoCD version in `sources/chart.yaml` is bumped, re-rendered, and pushed to Git, ArgoCD detects the change and performs a rolling update of its own pods.

---

## Sync Policy

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

## How to Trigger a Sync

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

## ArgoCD Projects

Applications are grouped into two ArgoCD Projects, which define security boundaries:

| Project | Source Paths | Cluster Permissions | Namespace Restrictions |
| ------- | ------------ | ------------------- | ---------------------- |
| `system` | `kubernetes/` | All cluster-scoped resources | All namespaces |
| `applications` | `kubernetes/` | Namespace-scoped resources only | All except `kube-system` |

The `system` project needs cluster-scoped permissions to install CRDs and cluster roles (e.g., Sealed Secrets). The `applications` project intentionally restricts applications to their own namespaces.
