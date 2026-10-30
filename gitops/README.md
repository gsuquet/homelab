# GitOps

Argo CD deploys the content of this folder. Refer to [GitOps with Argo CD](../docs/explanation/gitops-with-argocd.md) for the design.

| Folder | Content |
| --- | --- |
| `platform/<component>/` | Platform components, for example Argo CD, cert-manager and the gateways. |
| `apps/<app>/` | Applications, for example Home Assistant. |
| `instances/<instance>.yaml` | The entry point for one instance. It lists the components and apps that the instance uses. |

## Layout of a component

Each component in `platform/` and `apps/` uses the rendered manifests pattern:

```text
<component>/
├── sources/
│   ├── Chart.yaml        # Umbrella chart. The upstream chart has an exact version.
│   ├── chart.env         # NAMESPACE for helm template.
│   ├── values.yaml       # Values for all instances
│   └── templates/        # namespace.yaml, and more manifests, for example an AppProject.
├── values/
│   └── <instance>.yaml   # Values for one instance
└── rendered/
    └── <instance>/       # Generated manifests. Do not edit.
```

`mise run manifests:render` writes `rendered/<instance>/` for each file in `values/`. It writes one file for each resource.

Each component uses this pattern. Each component ships its own `Namespace`, with the Pod Security labels and the sync wave `-2`. Its CRDs have the sync wave `-1`. Refer to [Add a GitOps component](../docs/how-to/add-gitops-component.md).

## Entry point of an instance

`instances/<instance>.yaml` lists the components of the instance. `schemas/gitops-instance.schema.json` validates it.

```yaml
apiVersion: infra.gsuquet.com/v1alpha1
kind: GitOpsInstance
instance: kind-local
platform:
  - name: argocd       # Folder in platform/. Also the name of the Application.
    namespace: argocd  # Destination namespace of the Application.
apps: []
```

The `platform` and `apps` ApplicationSets read this file from Git. They make one Application for each item. The Application syncs `<group>/<name>/rendered/<instance>/`.
