# GitOps

Argo CD deploys the content of this folder. Refer to [GitOps with Argo CD](../docs/explanation/gitops-with-argocd.md) for the design.

| Folder | Content |
| --- | --- |
| `infrastructure/<component>/` | Components that can change cluster-scoped resources, for example Argo CD, cert-manager and the gateways. |
| `apps/<app>/` | Applications, for example Home Assistant. |
| `clusters/<cluster>/` | All that is specific to one cluster: the list of components, the value overrides and the rendered manifests. |

## Layout

```text
gitops/
├── infrastructure/<component>/sources/
│   ├── Chart.yaml              # Umbrella chart. The upstream chart has an exact version.
│   ├── values.yaml             # Values for all clusters
│   └── templates/              # namespace.yaml, and more manifests
├── apps/<app>/sources/         # The same layout
└── clusters/<cluster>/
    ├── cluster.yaml            # Entry point: the components of the cluster
    ├── values/<component>.yaml # Optional. Values for this cluster only
    └── rendered/<component>/   # Generated manifests. Do not edit.
```

`mise run manifests:render` renders each component in `cluster.yaml` to `clusters/<cluster>/rendered/<component>/`. It writes one file for each resource, with the name `<kind>-<name>.yaml`.

Each component uses this pattern. Each component ships its own `Namespace`, with the Pod Security labels and the sync wave `-2`. Its CRDs have the sync wave `-1`. Refer to [Add a GitOps component](../docs/how-to/add-gitops-component.md).

## Entry point of a cluster

`clusters/<cluster>/cluster.yaml` lists the components of the cluster. `schemas/gitops-cluster.schema.json` validates it.

```yaml
apiVersion: infra.gsuquet.com/v1alpha1
kind: GitOpsCluster
name: kind-local            # Equal to the folder name and to the Terraform instance
infrastructure:
  - name: argocd            # Folder in infrastructure/. Also the name of the Application.
    namespace: argocd       # Destination namespace of the Application.
apps:
  - name: web
    namespace: web
    dependsOn:              # Optional. Argo CD syncs web after argocd is Healthy.
      - argocd
```

The `argocd` component renders one Application for each item. `dependsOn` sets the sync wave of the Application.
