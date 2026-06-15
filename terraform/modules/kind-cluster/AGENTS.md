# AGENTS.md — kind-cluster Terraform module

## Purpose

This Terraform module creates a local [Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker)
cluster using the [tehcyx/kind](https://registry.terraform.io/providers/tehcyx/kind/latest/docs) provider.
It is used for two purposes in this repository:

1. **Local development** — spin up a lightweight Kubernetes environment on a developer's machine
2. **Staging** — mirror the production cluster topology with matching CIDRs and node labels

## Provider

`tehcyx/kind` 0.11.0 — pinned for reproducibility.

## Key design decisions

- **Node image is digest-pinned** (`image:tag@sha256:digest`) to guarantee reproducibility
  and prevent supply-chain attacks. Always update all three variables (`node_image`,
  `node_image_tag`, `node_image_digest`) together when upgrading Kubernetes.
- **Kubeconfig is written to `~/.kube/kind-<name>`** by default to avoid merging into
  the default kubeconfig and interfering with other clusters.
- **Networking variables default to empty** — when empty, Kind uses its own defaults.
  Set `pod_subnet` and `service_subnet` to match the production cluster when using this
  module as a staging environment.
- **Port mappings apply to all control-plane nodes** — this is the standard Kind pattern
  for exposing an ingress controller.

## Variables that require attention

| Variable | Default | Notes |
|---|---|---|
| `name` | — | **Required.** Lowercase alphanumeric and hyphens. |
| `node_image_digest` | Current k8s release | Update when bumping `node_image_tag`. |
| `disable_default_cni` | `false` | Set `true` before installing Cilium/Calico. |
| `pod_subnet` / `service_subnet` | Kind defaults | Override for staging environments. |

## Outputs consumed by downstream modules

Downstream root modules typically use these outputs to configure providers:

```hcl
provider "kubernetes" {
  host                   = module.cluster.endpoint
  client_certificate     = base64decode(module.cluster.client_certificate)
  client_key             = base64decode(module.cluster.client_key)
  cluster_ca_certificate = base64decode(module.cluster.cluster_ca_certificate)
}
```

## Modifying this module

- **`locals.tf`** — computed values only (image string, kubeconfig path, node lists)
- **`variables.tf`** — all inputs; always provide a `description` and sensible `default`
- **`main.tf`** — single `kind_cluster.this` resource; use `dynamic` blocks for optional config
- **`outputs.tf`** — expose all attributes needed by downstream providers; mark secrets `sensitive`
- **`terraform.tf`** — only bump the provider version when intentionally upgrading

## Do not

- Add a second `kind_cluster` resource — create a new module invocation instead
- Remove the `wait_for_ready = true` — downstream providers will fail to connect
- Use `latest` or remove digest pinning — it breaks reproducibility
