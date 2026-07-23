# How to Render Manifests

This project pre-renders Helm charts to plain YAML and commits the output. When a chart's `sources/chart.yaml` or `sources/values.yaml` changes, the rendered output in `manifests/` must be regenerated.

See [Rendered Manifests Pattern](../explanation/rendered-manifests-pattern.md) for background on why this approach is used.

---

## When Re-rendering is Needed

You need to re-render when you change:

- `kubernetes/bootstrap/argo-cd/sources/chart.yaml` (ArgoCD version bump)
- `kubernetes/bootstrap/argo-cd/sources/values.yaml` (ArgoCD configuration change)
- Any other `**/sources/Chart.yaml` or `**/sources/values.yaml` file added in the future

You do **not** need to re-render when you:

- Add or modify plain YAML application manifests under `kubernetes/applications/`
- Change Ansible playbooks or roles
- Modify non-chart configuration

---

## Re-render with mise

From the repository root:

```bash
mise run manifests:render
```

The script:

1. Finds all `**/sources/Chart.yaml` files in the repository
2. For each chart, runs `helm dependency update` to fetch or update chart dependencies
3. Runs `helm template <component> <source_dir> -f values.yaml` to produce `manifests/install.yaml`
4. Splits `install.yaml` into individual files named after each Kubernetes resource (using `# Source:` comments)
5. Handles duplicate filenames by appending a numeric suffix
6. Updates `kustomization.yaml` to list all generated files

The script prints a summary of how many charts were rendered and whether any errors occurred.

---

## The Pre-commit Hook

You rarely need to run `mise run manifests:render` manually. The pre-commit hook does it automatically:

```yaml
# .pre-commit-config.yaml
- id: render-manifests
  name: Render Kubernetes manifests
  language: system
  entry: mise run manifests:render
  files: 'kubernetes/**/sources/.*\.yaml'
  pass_filenames: false
```

This hook fires on `git commit` when any `sources/*.yaml` file is staged. It renders all charts and stages the updated `manifests/` files before the commit completes.

This means:

- If you update `sources/chart.yaml` and run `git commit`, the hook re-renders and includes the updated `manifests/` in the same commit automatically
- You only need to run `mise run manifests:render` manually if you want to inspect the output before committing

---

## Validate That Manifests Are Current

To check whether the committed manifests match what the current sources would produce:

```bash
mise run manifests:check
```

This runs `manifests:render` and checks whether `kubernetes/**/manifests/` files changed. It exits with a non-zero code if they are out of date. This check is used in CI to prevent un-rendered changes from being merged.
