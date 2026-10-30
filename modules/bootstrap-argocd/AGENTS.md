# AGENTS.md: bootstrap-argocd module

## Purpose

Installs Argo CD on a new cluster. The module applies the rendered manifests of the `argocd` GitOps component: `gitops/platform/argocd/rendered/<instance>/`. These manifests contain Argo CD, the `platform` and `apps` AppProjects and the `platform` and `apps` ApplicationSets. The `platform` ApplicationSet makes the `argocd` Application, and this Application syncs the same folder from Git. Thus Argo CD manages itself after the bootstrap.

## Design decisions

- **One source of truth.** The module has no chart and no values. The Helm values are in `gitops/platform/argocd/`. To change Argo CD, change `sources/values.yaml` or `values/<instance>.yaml`, run `mise run manifests:render` and merge. Argo CD then applies the change to itself.
- **Terraform creates, Argo CD updates.** Each `kubectl_manifest` has `ignore_changes = all`. Terraform creates a resource when it is missing, and does not update it. Thus Terraform and Argo CD do not fight over the same fields.
- **Three steps.** `foundation` applies the namespace and the CRDs. `components` applies the Argo CD components and waits for the rollouts. `argocd_resources` applies the AppProjects and ApplicationSets last.
- **Split at plan time, with no data source.** As in `bootstrap-gateway-api`, `locals` splits each file on `---` and keys each document by `<kind>/<namespace>/<name>`. Terraform knows the keys at plan time, also before the cluster exists.
- **Server-Side Apply.** The Argo CD CRDs are too large for client-side apply.

## Inputs that need attention

| Variable | Notes |
| --- | --- |
| `manifests_dir` | The rendered folder of the instance. The ApplicationSets in it read `gitops/instances/<instance>.yaml` from Git. |

## Do not

- Do not add a `helm_release` for Argo CD. Helm and Argo CD would then both own the resources.
- Do not remove `ignore_changes = all`. Terraform would then revert the upgrades that Argo CD applies from Git.
- Do not edit the files in `rendered/`. Run `mise run manifests:render`.
