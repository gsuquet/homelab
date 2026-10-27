# GitOps

Argo CD deploys the content of this folder. Phase 2 of the migration fills it.

| Folder | Content |
| --- | --- |
| `platform/<component>/` | Platform components, for example Cilium, cert-manager and the gateways. |
| `apps/<app>/` | Applications, for example Home Assistant. |
| `instances/<instance>.yaml` | The entry point for one instance. It lists the components and apps that the instance uses. |

## Layout of a component

Each component in `platform/` and `apps/` uses the rendered manifests pattern:

```text
<component>/
├── sources/
│   ├── Chart.yaml        # Upstream Helm chart, with an exact version
│   └── values.yaml       # Values for all instances
├── values/
│   └── <instance>.yaml   # Values for one instance
└── rendered/
    └── <instance>/       # Generated manifests. Do not edit.
```

`mise run manifests:render` will write `rendered/<instance>/` for each instance that has a values file. This change comes with the first component, in Phase 2.
