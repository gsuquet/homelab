# Terraform Modules Reference

This page lists the Terraform modules in `modules/`. The name of each module starts with its layer: `substrate-`, `cluster-` or `bootstrap-`.

## Available Modules

| Module | Description | Location |
|--------|-------------|----------|
| [`cluster-kind`](cluster-kind/index.md) | Creates a local Kind (Kubernetes in Docker) cluster | `modules/cluster-kind/` |
| [`bootstrap-gateway-api`](bootstrap-gateway-api/index.md) | Installs the Gateway API CRDs | `modules/bootstrap-gateway-api/` |
| [`bootstrap-cilium`](bootstrap-cilium/index.md) | Installs Cilium as the cluster CNI | `modules/bootstrap-cilium/` |
| [`bootstrap-coredns`](bootstrap-coredns/index.md) | Adds CoreDNS rewrite rules that send host names to a Service | `modules/bootstrap-coredns/` |
| [`bootstrap-cert-manager`](bootstrap-cert-manager/index.md) | Installs cert-manager and its cluster issuers | `modules/bootstrap-cert-manager/` |
| [`bootstrap-argocd`](bootstrap-argocd/index.md) | Installs Argo CD one time. Then Argo CD manages itself from `gitops/` | `modules/bootstrap-argocd/` |

In Phase 2, the GitOps infrastructure (`gitops/infrastructure/`) takes over Gateway API and cert-manager.

---

## Usage

terraform-docs updates the module reference pages. Run:

```bash
mise run doc:generate
```
