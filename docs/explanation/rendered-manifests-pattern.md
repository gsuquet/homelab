# Explanation: Rendered Manifests Pattern

This document explains why Helm charts in this project are pre-rendered to plain YAML and committed to Git, rather than having ArgoCD render them at sync time.

---

## The Problem with Helm at Sync Time

ArgoCD supports Helm natively — you can point an Application at a Helm chart and ArgoCD will run `helm template` during sync. This is convenient, but introduces dependencies:

1. **Network access at sync time**: ArgoCD must reach the upstream Helm chart repository every time it syncs. If the upstream is unavailable or the chart version is yanked, syncs fail.
2. **Opacity**: The actual YAML applied to the cluster is not visible in the repository. You cannot `git diff` two versions of ArgoCD and see exactly what changed.
3. **Reproducibility**: Helm rendering can produce different output depending on the Helm version, plugin availability, and chart repository state.

For self-managing ArgoCD specifically, the problem is acute: if ArgoCD is broken and needs to re-apply its own manifests, it cannot do so if it cannot reach the upstream chart repository.

---

## The Solution: Render Locally, Commit the Output

This project renders Helm charts locally using `mise run manifests:render` and commits the resulting plain YAML files to Git. ArgoCD then reads these YAML files directly without needing Helm at all.

```ascii
Developer workstation                Git repository
┌──────────────────────┐             ┌─────────────────────────┐
│  sources/chart.yaml  │             │  manifests/install.yaml  │
│  sources/values.yaml │  →  render  │  manifests/argocd-*.yaml │
│  (Helm chart source) │             │  (Plain YAML, committed) │
└──────────────────────┘             └─────────────────────────┘
                                               │
                                               ▼ (ArgoCD reads YAML directly)
                                     ┌─────────────────────────┐
                                     │  Kubernetes cluster      │
                                     └─────────────────────────┘
```

The render step is automated via a pre-commit hook — when `sources/*.yaml` files are staged, the hook runs `mise run manifests:render` and includes the updated `manifests/` files in the same commit.

---

## How the Render Script Works

`.mise/tasks/manifests/render.sh`:

1. Finds all `**/sources/Chart.yaml` files in the repository
2. Runs `helm dependency update <source_dir>` to download the upstream chart
3. Runs `helm template <component> <source_dir> -f <source_dir>/values.yaml` to produce `manifests/install.yaml`
4. Splits `install.yaml` into individual files at `# Source: <filename>` comment boundaries
5. Each split file is named after its Kubernetes resource (e.g., `argocd-server-deployment.yaml`)
6. Updates `kustomization.yaml` to list all generated files

ArgoCD uses Kustomize to apply the split files — the `kustomization.yaml` lists them all.

---

## The Role of Kustomize

The `kustomization.yaml` file in the manifests directory:

```yaml
resources:
  - argocd-application-controller-clusterrole.yaml
  - argocd-application-controller-clusterrolebinding.yaml
  - argocd-application-controller-statefulset.yaml
  # ... (all split files)
```

ArgoCD is configured to use Kustomize for this directory. Kustomize reads `kustomization.yaml`, assembles all listed resources, and applies them as a single batch. This is why ArgoCD can apply the directory without Helm — Kustomize handles the assembly from plain YAML.

---

## Trade-offs

| Property | Rendered manifests | Helm at sync time |
| -------- | ------------------ | -------------------|
| Upstream network dependency | None at sync time | Required every sync |
| Diff visibility | Full YAML diff in Git | Not visible in Git |
| Reproducibility | Locked to committed output | Depends on Helm version and chart registry |
| Git churn on upgrades | High (many YAML files change) | Low (one line in chart.yaml) |
| Offline sync capability | Yes | No |

The main cost is **Git churn**: upgrading ArgoCD from one version to the next produces a large diff in `manifests/` with hundreds of changed lines across many files. This is acceptable here because the benefit — full transparency and offline capability — outweighs the noise in the Git history.

For user application manifests under `kubernetes/applications/`, this pattern does not apply because those apps do not use Helm charts in this project. They are written as plain YAML directly.
