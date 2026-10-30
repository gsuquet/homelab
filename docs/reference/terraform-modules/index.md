# Terraform Modules Reference

This page lists the Terraform modules in `modules/`. The name of each module starts with its layer: `substrate-`, `cluster-` or `bootstrap-`.

## Available Modules

| Module | Description | Location |
|--------|-------------|----------|
| [`cluster-kind`](cluster-kind/index.md) | Creates a local Kind (Kubernetes in Docker) cluster | `modules/cluster-kind/` |
| [`bootstrap-gateway-api`](bootstrap-gateway-api/index.md) | Installs the Gateway API CRDs | `modules/bootstrap-gateway-api/` |
| [`bootstrap-cilium`](bootstrap-cilium/index.md) | Installs Cilium as the cluster CNI | `modules/bootstrap-cilium/` |
| [`bootstrap-cert-manager`](bootstrap-cert-manager/index.md) | Installs cert-manager and its cluster issuers | `modules/bootstrap-cert-manager/` |
| [`bootstrap-agent-sandbox`](bootstrap-agent-sandbox/index.md) | Installs the agent-sandbox controller | `modules/bootstrap-agent-sandbox/` |
| [`bootstrap-argocd`](bootstrap-argocd/index.md) | Installs Argo CD one time. Then Argo CD manages itself from `gitops/` | `modules/bootstrap-argocd/` |

In Phase 2, the GitOps platform (`gitops/platform/`) takes over Gateway API, cert-manager and agent-sandbox.

---

## Usage

terraform-docs updates the module reference pages. Run:

```bash
mise run doc:generate
```
