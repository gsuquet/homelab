# AGENTS.md — bootstrap-gateway-api Terraform module

## Purpose

Deploys official Kubernetes [Gateway API](https://gateway-api.sigs.k8s.io/) CustomResourceDefinitions
(`gateway.networking.k8s.io`), establishing the prerequisite APIs required by Gateway controllers
(e.g., Cilium Gateway API, Envoy Gateway, cert-manager Gateway API solvers).

## Key design decisions

- **Bundled GitOps release manifests.** Pre-packaged official release manifests (`standard-install.yaml`
  and `experimental-install.yaml`) are vendored under `manifests/` for reproducibility, offline readiness,
  and git auditability.
- **One resource block for both channels.** `local.manifest_file` picks `<channel>-install.yaml`,
  and `kubectl_manifest.this` applies each document in it.
- **Split at plan time, with no data source.** `locals` splits the file on `---` and keys each
  document by `<kind>/<metadata.name>`. Terraform knows the keys at plan time, also before the
  cluster exists. Do not go back to `data.kubectl_file_documents`: with `depends_on` on the cluster
  module, its keys are only known after apply, and `for_each` fails on a new cluster.
- **Server-Side Apply enabled by default.** CRD manifests in Gateway API exceed 1MB in aggregate.
  `server_side_apply = true` and `force_conflicts = true` bypass Kubernetes client-side 256KB
  annotation limits (`kubectl.kubernetes.io/last-applied-configuration`).
- **Channel selection.** Defaults to `channel = "standard"`. Switch to `channel = "experimental"`
  if experimental route types or policies (`TCPRoute`, `UDPRoute`, `TLSRoute`, `BackendTLSPolicy`)
  are required.

## Variables that require attention

| Variable | Notes |
|---|---|
| `channel` | Release channel: `"standard"` (default) or `"experimental"`. |
| `server_side_apply` | Defaults to `true`; recommended for large CRD schemas. |
| `force_conflicts` | Overwrites any existing field manager conflicts during Server-Side Apply. |

## Outputs consumed by downstream modules

Downstream modules (such as `cilium` or `cert-manager`) that require Gateway API CRDs can declare
`depends_on = [module.gateway_api]` to make sure that API registration completes before Gateway controller
initialization.

## Modifying this module

- **`manifests/`** — contains the official upstream `standard-install.yaml` and `experimental-install.yaml`.
- **`main.tf`** — splits the manifests in `locals` and applies them with `kubectl_manifest.this`.
- **`variables.tf`** — channel and apply behavior toggles.
- **`outputs.tf`** — channel, version, and deployed CRD identifiers.

## Do not

- Disable `server_side_apply` unless running against an API server that does not support it.
- Edit `manifests/*.yaml` manually; update by pulling official release assets from `kubernetes-sigs/gateway-api`.
