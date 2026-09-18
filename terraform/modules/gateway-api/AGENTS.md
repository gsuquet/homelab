# AGENTS.md — gateway-api Terraform module

## Purpose

Deploys official Kubernetes [Gateway API](https://gateway-api.sigs.k8s.io/) CustomResourceDefinitions
(`gateway.networking.k8s.io`), establishing the prerequisite APIs required by Gateway controllers
(e.g., Cilium Gateway API, Envoy Gateway, cert-manager Gateway API solvers).

## Key design decisions

- **Bundled GitOps release manifests.** Pre-packaged official release manifests (`standard-install.yaml`
  and `experimental-install.yaml`) are vendored under `manifests/` for reproducibility, offline readiness,
  and git auditability.
- **Two explicit channel resource blocks.** Uses two distinct `kubectl_manifest` resource blocks
  (`kubectl_manifest.standard` and `kubectl_manifest.experimental`). The active resource is determined
  dynamically by `var.channel == "standard"` or `var.channel == "experimental"`.
- **Dynamic document parsing via `kubectl_file_documents`.** The multi-document YAML release files
  are split using `data.kubectl_file_documents`, allowing each CRD to be tracked as an independent
  resource in Terraform state.
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
`depends_on = [module.gateway_api]` to ensure API registration completes before Gateway controller
initialization.

## Modifying this module

- **`manifests/`** — contains the official upstream `standard-install.yaml` and `experimental-install.yaml`.
- **`crds.tf`** — parses manifests with `kubectl_file_documents` and provisions resources.
- **`variables.tf`** — channel and apply behavior toggles.
- **`outputs.tf`** — channel, version, and deployed CRD identifiers.

## Do not

- Disable `server_side_apply` unless running against an API server that does not support it.
- Edit `manifests/*.yaml` manually; update by pulling official release assets from `kubernetes-sigs/gateway-api`.
