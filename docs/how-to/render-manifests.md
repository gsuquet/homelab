# Render manifests

This guide shows how to update the rendered manifests in `gitops/clusters/<cluster>/rendered/` after a change to a GitOps component.

Render after a change to one of these files:

- `gitops/<group>/<component>/sources/`, for example the chart version in `Chart.yaml` or a value in `values.yaml`;
- `gitops/clusters/<cluster>/values/<component>.yaml`;
- `gitops/clusters/<cluster>/cluster.yaml`.

## Render

1. Run the render from the root of the repository:

   ```bash
   mise run manifests:render
   ```

2. Examine the changes in the rendered folders:

   ```bash
   git status -- gitops/clusters/
   git diff -- gitops/clusters/
   ```

   Each CRD in the output has the annotation `argocd.argoproj.io/sync-wave: "-1"` and the option `Prune=false` in `argocd.argoproj.io/sync-options`. The task adds both. Do not add them to the chart.

   If a chart bump removes a CRD, the sync does not delete it, because of `Prune=false`. The Application stays `OutOfSync`. Delete the CRD by hand when you are sure that nothing uses its custom resources:

   ```bash
   kubectl delete crd <name>
   ```

   Refer to [Argo CD: no prune resources](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#no-prune-resources).

3. Commit the sources and the rendered files together, and open a pull request.

The `render-manifests` pre-commit hook does step 1 for you. On a commit that changes one of these files, it renders and stages `gitops/**/rendered/`. It does not commit for you or open a pull request. Run the task yourself to examine the output before the commit.

## Check that the manifests are current

```bash
mise run manifests:check
```

The task renders again and fails when the rendered files change. CI runs it on each pull request that changes `gitops/`.

To check the rendered files against the Kubernetes schemas, run:

```bash
mise run manifests:validate
```

## Fix a pull request that fails `manifests:check`

1. Check out the branch of the pull request.
2. Run `mise run manifests:render`.
3. Commit the rendered files and push the branch.

## Related pages

- [Rendered manifests pattern](../explanation/rendered-manifests-pattern.md): why the repository commits the output of Helm.
- [Mise tasks](../reference/mise-tasks.md): the steps and the errors of each task.
- [GitOps layout](../reference/gitops-layout.md#rendered-files): the file names and the values order.
