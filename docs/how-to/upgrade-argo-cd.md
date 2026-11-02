# Upgrade Argo CD

This guide shows how to upgrade Argo CD, or change its settings, on all the clusters. Argo CD manages itself: a merged pull request upgrades it.

## Before you start

- You ran `mise install`.
- You know the target version of the `argo-cd` chart. The releases are in [argoproj/argo-helm](https://github.com/argoproj/argo-helm/releases). The chart version is not the Argo CD version.

## Upgrade

1. Read the upgrade notes of the [Argo CD versions](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/overview/) between the current version and the target version.
2. Make a branch from `main`.
3. In `gitops/infrastructure/argocd/sources/Chart.yaml`, set the `version` of the `argo-cd` dependency to the exact target version:

   ```yaml
   dependencies:
     - name: argo-cd
       version: "<version>"
       repository: https://argoproj.github.io/argo-helm
   ```

   To change a setting, change `sources/values.yaml` instead, or the file `gitops/clusters/<cluster>/values/argocd.yaml` for one cluster.

4. Render the manifests:

   ```bash
   mise run manifests:render
   ```

5. Examine the diff of `gitops/clusters/*/rendered/argocd/`. Look for removed resources, changed selectors and changed CRDs.
6. Run `mise run lint`.
7. Commit the change with the rendered files, and open a pull request.
8. Merge the pull request.

The `argocd` Application syncs the new manifests within about 3 minutes, and Argo CD upgrades itself. To start the sync at once, refer to [Force a sync](force-a-sync.md).

## Upgrade from a Renovate pull request

Renovate changes `Chart.yaml`, but it does not render. Its pull request fails `mise run manifests:check` in CI.

1. Check out the branch of the pull request.
2. Do steps 1 and 4 to 6 of [Upgrade](#upgrade).
3. Commit the rendered files, and push the branch.
4. Merge the pull request when CI passes.

## Check the upgrade

1. Watch the pods restart:

   ```bash
   kubectl -n argocd get pods -w
   ```

2. Check the image of the server:

   ```bash
   kubectl -n argocd get deployment argocd-server \
     -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
   ```

3. Check that the `argocd` Application is `Synced` and `Healthy`:

   ```bash
   kubectl -n argocd get application argocd
   ```

## Related pages

- [GitOps with Argo CD](../explanation/gitops-with-argocd.md#why-argo-cd-manages-itself): why a pull request upgrades Argo CD.
- [GitOps layout](../reference/gitops-layout.md#argo-cd-settings): the settings in `values.yaml`.
- [Render manifests](render-manifests.md)
