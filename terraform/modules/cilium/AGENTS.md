# AGENTS.md — cilium Terraform module

## Purpose

Installs [Cilium](https://cilium.io/) as the cluster's CNI via its official
Helm chart, providing CNI networking, eBPF-based kube-proxy replacement,
L3-L7 network policies, transparent pod-to-pod encryption, and Hubble
observability.

## Key design decisions

- **OCI chart repository.** The chart is pulled directly from the official OCI
  registry (`oci://quay.io/cilium/charts/cilium`) rather than a classic Helm repo
  — no `helm repo add` needed, and OCI artifacts are cosign-signed.
- **`kube-system` by default, not a dedicated namespace.** Cilium is a CNI;
  it conventionally lives in `kube-system`, which already exists on every
  cluster. `create_namespace` exists for the rare case of overriding
  `namespace`, but don't reach for it without a reason.
- **`hubble_relay_enabled` / `hubble_ui_enabled` live here, default `false`.**
  Hubble Relay and the Hubble UI are sub-templates of the *same* Cilium Helm
  chart/release — they are not a separate chart. That means they **cannot**
  be managed by a second, independent `helm_release` without both resources
  fighting over the same release name (Helm will refuse the second
  `install`/`upgrade`).
- **Template-driven values with static uppercase placeholders.** The upstream
  values file (`templates/cilium-values.yaml.tftpl`) uses static uppercase
  placeholders (`${VARIABLE_NAME}`) rendered via `templatefile()` in
  `helm-chart.tf`. All conditionals and defaults are computed in `locals.tf`
  under `local.cilium_values`, making the template directly renderable
  locally via `envsubst` (or equivalent tools) to output rendered manifests.
- **`k8s_service_host` / `k8s_service_port` are opt-in, not defaulted.**
  They matter mainly for `kube_proxy_replacement = true` on clusters (like
  kind) where the API server isn't reachable via the in-cluster service.
  Left empty, the chart's own detection applies — don't hardcode a kind-
  specific default here, since this module also targets managed cloud clusters.
- **Encryption defaults on (WireGuard).** Pod-to-pod traffic is encrypted by
  default; `encryption_type` also supports `ipsec`.
- **Bandwidth Manager & BBR.** Enabled by default (`bandwidth_manager_enabled = true`,
  `bandwidth_manager_bbr = true`) to provide eBPF EDT (Earliest Departure Time)
  packet pacing and BBR TCP congestion control for Pods.

## Variables that require attention

| Variable | Notes |
|---|---|
| `hubble_relay_enabled` / `hubble_ui_enabled` | Flipped on when Hubble Relay or UI components are needed. |
| `k8s_service_host` / `k8s_service_port` | Set explicitly for kind; leave empty on managed clouds unless proven necessary. |
| `policy_enforcement_mode` | Allows explicit `CiliumNetworkPolicy` resources per workload without enforcing global default-deny upfront. |

## Outputs consumed by downstream modules

`hubble_relay_enabled` / `hubble_ui_enabled` let sibling modules or root
compositions check current state before deciding what to enable.
`namespace` / `release_name` are for anything that needs to target the same
Helm release or namespace (e.g. a `NetworkPolicy` scoping Hubble Relay
access).

## Modifying this module

- **`locals.tf`** — computed static uppercase template values (`local.cilium_values`);
  handle any conditionals or platform logic here so the template stays static
- **`templates/cilium-values.yaml.tftpl`** — full upstream values file with static
  `${VARIABLE_NAME}` placeholders for variables and `$${1}` for Envoy regexes
- **`variables.tf`** — defined module variables with validations and defaults
- **`helm-chart.tf`** — single `helm_release.cilium` resource rendering the template
  via `templatefile()` with `local.cilium_values`
- **`namespace.tf`** — conditional on `create_namespace`; don't remove the
  `count` guard, `kube-system` must never be created/owned by Terraform
- **`outputs.tf`** — expose anything downstream modules need to reference this release/namespace

## Do not

- Add a second `helm_release` targeting the same chart/release for Hubble
  relay/UI — it will fail at apply time (see above)
- Hardcode `k8s_service_host`/`k8s_service_port` defaults for kind — this
  module also targets GKE
- Remove the digest/version pin on chart installation or default to `latest`
