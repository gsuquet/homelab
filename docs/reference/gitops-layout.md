# GitOps layout

This page describes the files in `gitops/`, how they render, and the settings of the Argo CD Applications. The reasons are in [GitOps with Argo CD](../explanation/gitops-with-argocd.md). The place of `gitops/` in the repository is in [Repository structure](repository-structure.md).

## Folders

```text
gitops/
├── infrastructure/<component>/sources/
│   ├── Chart.yaml              # Umbrella chart. Each dependency has an exact version.
│   ├── values.yaml             # Values for all clusters
│   └── templates/
│       └── namespace.yaml      # The Namespace of the component. Required.
├── apps/<app>/sources/         # The same layout
└── clusters/<cluster>/
    ├── cluster.yaml            # Entry point: the components of the cluster
    ├── values/<component>.yaml # Optional. Values for this cluster only
    └── rendered/<component>/   # Generated. manifests:render writes it.
```

| Folder | Content | AppProject |
| --- | --- | --- |
| `gitops/infrastructure/<component>/` | A component that can change cluster-scoped resources, for example Argo CD or cert-manager. | `infrastructure` |
| `gitops/apps/<app>/` | An application. | `apps` |
| `gitops/clusters/<cluster>/` | The files of one cluster. The name is equal to the Terraform instance in `instances/<cluster>/`. | Not applicable |

Git does not track `sources/charts/` and `sources/Chart.lock`. `helm dependency update` writes them during the render.

## `cluster.yaml`

`gitops/clusters/<cluster>/cluster.yaml` lists the components of the cluster. `schemas/gitops-cluster.schema.json` validates it.

```yaml
apiVersion: infra.gsuquet.com/v1alpha1
kind: GitOpsCluster
name: kind-local
infrastructure:
  - name: argocd
    namespace: argocd
apps:
  - name: web
    namespace: web
    dependsOn:
      - argocd
```

| Field | Required | Value |
| --- | --- | --- |
| `apiVersion` | Yes | `infra.gsuquet.com/v1alpha1` |
| `kind` | Yes | `GitOpsCluster` |
| `name` | Yes | The cluster name. Equal to the folder name and to the Terraform instance. DNS-1123 label, maximum 40 characters. |
| `infrastructure` | Yes | The components from `gitops/infrastructure/`. Must contain `argocd`. |
| `apps` | Yes | The components from `gitops/apps/`. Can be `[]`. |
| `<list>[].name` | Yes | The folder name of the component, and the name of its Application. DNS-1123 label, maximum 53 characters. Unique in the cluster. |
| `<list>[].namespace` | Yes | The destination namespace of the Application. DNS-1123 label, maximum 63 characters. Unique in the cluster. |
| `<list>[].dependsOn` | No | Names of components of the same cluster, in either list. They must be `Healthy` before Argo CD syncs this component. Not permitted on `argocd`. |

## Values

A component renders with these values, in this order. A value in a later item replaces the same value in an earlier item.

1. `gitops/<group>/<component>/sources/values.yaml`: the values for all clusters.
2. `gitops.cluster`: the content of `cluster.yaml`. The `argocd` chart reads it to make the Applications.
3. `gitops/clusters/<cluster>/values/<component>.yaml`: the values for one cluster. Optional.

The render also sets the Helm namespace to the `namespace` of the component in `cluster.yaml`.

The `argocd` chart has these GitOps values:

| Value | Default | Meaning |
| --- | --- | --- |
| `gitops.repoURL` | `https://github.com/gsuquet/homelab.git` | The repository that the Applications and the AppProjects use. |
| `gitops.targetRevision` | `main` | The Git revision that each Application syncs. |
| `gitops.cluster` | `{}` | The content of `cluster.yaml`. The render sets it. |

## Rendered files

`mise run manifests:render` renders each component of `cluster.yaml` to `gitops/clusters/<cluster>/rendered/<component>/`. The scripts and the options of the task are in [Mise tasks](mise-tasks.md).

| Rule | Value |
| --- | --- |
| File name | `<kind>-<name>.yaml`, in lowercase. One file for each resource. |
| Prefix of an upstream resource | `upstream--`. A resource comes from an upstream chart when the second segment of its `# Source:` path is `charts`. |
| CRDs | The render includes the CRDs of the `crds/` folder of a chart. |
| Duplicates | Two resources with the same kind and name stop the task. |
| Removed components | The task deletes `rendered/` before it renders, thus the folder of a removed component goes away. |

The Conftest policies read the origin of a resource from the `upstream--` prefix.

## Applications

The `argocd` chart renders one Application for each item of `cluster.yaml`, in `rendered/argocd/application-<component>.yaml`.

| Field | Value |
| --- | --- |
| `metadata.name` | The `name` of the item |
| `metadata.namespace` | `argocd` |
| `spec.project` | `infrastructure` or `apps`: the list of the item |
| `spec.source.repoURL` | `gitops.repoURL` |
| `spec.source.targetRevision` | `gitops.targetRevision` |
| `spec.source.path` | `gitops/clusters/<cluster>/rendered/<component>` |
| `spec.destination` | `https://kubernetes.default.svc`, the `namespace` of the item |
| `spec.syncPolicy.automated` | `prune: true`, `selfHeal: true` |
| `spec.syncPolicy.syncOptions` | `ServerSideApply=true` |
| `spec.syncPolicy.retry` | `limit: 5`, backoff `10s`, factor `2`, maximum `3m` |
| `metadata.finalizers` | None |

## Sync waves

Argo CD applies the resources of one Application in waves.

| Wave | Resources |
| --- | --- |
| `-2` | `Namespace` |
| `-1` | `CustomResourceDefinition` |
| `0` | All other resources (default) |
| `1` or more | The Applications, in `rendered/argocd/`. Also the resources that need the custom resources of the same component, for example a `ClusterIssuer` after cert-manager. |

The wave of an Application is `1` without `dependsOn`. Else it is the wave of its deepest dependency plus 1. The render fails when `dependsOn` names a component that is not in the cluster, or when it makes a cycle.

## Argo CD settings

The values are in `gitops/infrastructure/argocd/sources/values.yaml`.

| Setting | Value | Reason |
| --- | --- | --- |
| Chart | `argo-cd` from `https://argoproj.github.io/argo-helm`, exact version in `Chart.yaml` | The upstream chart. |
| Diff | Server-side (`controller.diff.server.side: true`) | It goes with server-side apply. Defaulted fields do not show as `OutOfSync`. |
| TLS | Off on the server (`server.insecure: true`) | TLS stops at the gateway or at `kubectl port-forward`. |
| Default role | `role:readonly` | A logged-in user without a role can look, but not change. |
| Admin user | On (`admin.enabled: true`) | The login to the UI. There is no SSO. |
| Exec | Off (`exec.enabled: false`) | No shell into pods from the UI. |
| Application health | A custom health check for `argoproj.io/Application` | The sync waves between components wait for each component. The `argocd` Application is always `Healthy`. |
| Sync timeout | 15 minutes (`controller.sync.timeout.seconds: "900"`) | A component that is not `Healthy` does not stop the syncs of the `argocd` Application. |
| Reconciliation | The chart default: `timeout.reconciliation: 120s`, `timeout.reconciliation.jitter: 60s` | Argo CD reads Git about every 2 to 3 minutes. |
| Resource exclusions | The chart defaults | The chart already excludes noisy resources. |
| Dex, notifications | Off (`dex.enabled: false`, `notifications.enabled: false`) | The platform does not configure them. |
| Resources | Memory request equal to the limit, a CPU request, no CPU limit | The cluster resource policy. Sized for a Raspberry Pi 4 with 8 GiB. |
| CRDs | `Prune=false`, sync wave `-1` | A deleted CRD deletes all the Applications. |
| `argocd` namespace | `Prune=false,Delete=false`, sync wave `-2` | Argo CD does not delete its own namespace. |
| `argocd-secret` | Rendered with no data, `Prune=false,Delete=false` | `argocd-server` does not start without this `Secret`. At its start, it adds its keys and makes `argocd-initial-admin-secret`. |

## AppProjects

| Project | Source | Cluster-scoped resources | Namespaces |
| --- | --- | --- | --- |
| `infrastructure` | `gitops.repoURL` | All | All |
| `apps` | `gitops.repoURL` | `Namespace` only | All, but not `kube-system` and `argocd` |

## Bootstrap

The `bootstrap-argocd` Terraform module installs Argo CD one time from `gitops/clusters/<cluster>/rendered/argocd/`. For `kind-local`, `instances/kind-local/main.tf` sets this folder.

| Step | Resources |
| --- | --- |
| 1 | `Namespace` and `CustomResourceDefinition` |
| 2 | All other resources, except the `argoproj.io` resources |
| 3 | The AppProjects and the `argocd` Application only |

- All the resources use server-side apply with the field manager `argocd-controller`.
- Each resource has `ignore_changes = all`. Terraform creates the resources, but it does not update them.
- A Helm hook Job gets a copy with the suffix `-bootstrap`, without the hook annotations and without its TTL.
- The plan stops when the folder has no Application named `argocd`.

## Checks

| Rule | Check |
| --- | --- |
| `cluster.yaml` complies with its schema, and `name` is equal to the folder name. | `mise run schemas:check` |
| Each cluster lists `argocd` in `infrastructure`. | `mise run schemas:check`, and the `bootstrap-argocd` module |
| Each `dependsOn` names a component of the cluster. | `mise run schemas:check`, and the render |
| Each component of `cluster.yaml` has `sources/Chart.yaml` and a `rendered/<component>/` folder that contains its Namespace. | `mise run schemas:check` |
| Each folder in `gitops/infrastructure/` and `gitops/apps/` has `sources/Chart.yaml` and `sources/templates/namespace.yaml`. | `mise run schemas:check` |
| Each dependency in `sources/Chart.yaml` has a `repository` that starts with `https://` or `oci://`. Git tracks no file in `sources/charts/`. | `mise run schemas:check` |
| Each file in `values/` names a component of the cluster. | `mise run schemas:check` |
| Each `Namespace` has the Pod Security labels `enforce`, `audit` and `warn`. | Conftest, `mise run lint:policy` |
| A `Namespace` has the sync wave `-2`. A `CustomResourceDefinition` has the sync wave `-1`. | Conftest |
| Each Application syncs `main`. | Conftest |
| No Application uses `CreateNamespace=true` or a resources finalizer. | Conftest |
| No `Secret` has plain values. | Conftest |
| The rendered files are equal to the output of the render. | `mise run manifests:check`, in CI |
| The rendered files comply with the Kubernetes schemas. | `mise run manifests:validate`, in CI |

The label rules are in [Labels and annotations](labels-and-annotations.md#checks).

## Related pages

- [GitOps with Argo CD](../explanation/gitops-with-argocd.md)
- [Rendered manifests pattern](../explanation/rendered-manifests-pattern.md)
- [Add a GitOps component](../how-to/add-gitops-component.md)
- [Render manifests](../how-to/render-manifests.md)
- [Mise tasks](mise-tasks.md)
- [Policies](policies.md)
- [Schemas](schemas.md)
