# How to Update ArgoCD

ArgoCD is installed from a Helm chart whose source is committed in `kubernetes/bootstrap/argo-cd/sources/`. Updating ArgoCD means bumping the chart version in that file, re-rendering the manifests, and pushing to Git. ArgoCD will then sync itself.

---

## 1. Find the New Chart Version

Check the [ArgoCD Helm chart releases](https://github.com/argoproj/argo-helm/releases) for the latest chart version. The chart version and the ArgoCD application version are different — the chart is at `kubernetes/bootstrap/argo-cd/sources/chart.yaml`.

---

## 2. Update the Chart Version

Open `kubernetes/bootstrap/argo-cd/sources/chart.yaml` and update the `version` field under the `argo-cd` dependency:

```yaml
dependencies:
  - name: argo-cd
    version: "9.5.3"        # updated from 9.5.2
    repository: https://argoproj.github.io/argo-helm
```

---

## 3. Re-render the Manifests

The rendered manifests in `kubernetes/bootstrap/argo-cd/manifests/` must be regenerated from the updated chart:

```bash
mise run manifests:render
```

This script:

1. Runs `helm dependency update` in `kubernetes/bootstrap/argo-cd/sources/`
2. Runs `helm template argocd sources/ -f sources/values.yaml` to produce `manifests/install.yaml`
3. Splits `install.yaml` into individual per-resource YAML files
4. Regenerates the `kustomization.yaml` file listing all split files

You can also skip the manual render — the pre-commit hook runs `mise run manifests:render` automatically before every commit when `sources/*.yaml` files change.

---

## 4. Commit and Push

Stage all changed files and commit:

```bash
git add kubernetes/bootstrap/argo-cd/
git commit -m "chore(argocd): bump from 9.5.2 to 9.5.3"
git push
```

The pre-commit hook re-renders manifests if needed, so even if you forgot step 3 the commit will include the correct rendered output.

---

## 5. Watch ArgoCD Self-Sync

ArgoCD manages its own deployment via the `argocd-bootstrap` Application. Once the commit lands on `main`, ArgoCD detects the change and performs a rolling update of its own components:

```bash
kubectl get pods -n argocd -w
```

Pods will restart one by one. The upgrade is complete when all pods show `Running` with the new image version:

```bash
kubectl get deployment argocd-server -n argocd \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```
