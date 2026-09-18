# AGENTS.md — agent-sandbox Terraform module

## Purpose

Installs the Kubernetes SIG Apps [agent-sandbox](https://github.com/kubernetes-sigs/agent-sandbox)
controller and CRDs (`agents.x-k8s.io` and `extensions.agents.x-k8s.io`), providing a declarative API
for isolated, stateful, singleton workloads tailored for AI agents and sandbox execution.

## Key design decisions

- **Vendored Helm chart.** The official Helm chart is vendored locally in `charts/agent-sandbox`
  for reproducible, offline-ready deployment without plan/apply-time Git dependencies.
- **Dedicated namespace.** Defaults to `agent-sandbox-system` managed via `kubernetes_namespace_v1`
  (`create_namespace = true`).
- **Extensions enabled by default.** `enable_extensions = true` activates the `SandboxTemplate`,
  `SandboxWarmPool`, and `SandboxClaim` controllers alongside the core `Sandbox` controller.
- **Template-driven values.** The values template file (`templates/agent-sandbox-values.yaml.tftpl`)
  uses uppercase placeholders (`${VARIABLE_NAME}`) rendered via `templatefile()` in `helm-chart.tf`.
- **Prometheus Operator integration.** An optional `prometheus_servicemonitor_enabled` toggle
  provisions a `ServiceMonitor` for scraping controller metrics.

## Variables that require attention

| Variable | Notes |
|---|---|
| `enable_extensions` | Deploys extensions controllers (warm pools, templates, claims). Defaults to `true`. |
| `image_tag` | Version tag of the controller image (`registry.k8s.io/agent-sandbox/agent-sandbox-controller`). Defaults to `v1.0.3`. |
| `prometheus_servicemonitor_enabled` | Deploys `ServiceMonitor` for Prometheus scraping. |

## Outputs consumed by downstream modules

`release_name`, `namespace`, and `extensions_enabled` provide references for downstream modules
deploying AI agent sandbox workloads or RBAC bindings.

## Modifying this module

- **`charts/agent-sandbox/`** — vendored upstream Helm chart.
- **`templates/agent-sandbox-values.yaml.tftpl`** — values template with uppercase placeholders.
- **`locals.tf`** — computes values passed to `templatefile()`.
- **`helm-chart.tf`** — `helm_release.agent_sandbox` resource definition.
- **`namespace.tf`** — conditional namespace creation.
- **`variables.tf`** / **`outputs.tf`** — input variables and outputs.

## Do not

- Modify vendored chart templates under `charts/agent-sandbox/templates/` directly; override settings
  via `templates/agent-sandbox-values.yaml.tftpl` instead.
