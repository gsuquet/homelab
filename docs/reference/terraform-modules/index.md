# Terraform Modules Reference

Technical documentation for Terraform modules provided in `terraform/modules/`.

## Available Modules

| Module | Description | Location |
|--------|-------------|----------|
| [`kind-cluster`](kind-cluster/index.md) | Provision local Kind (Kubernetes in Docker) development clusters | `terraform/modules/kind-cluster/` |
| [`cilium`](cilium/index.md) | Install Cilium as the cluster CNI (pure networking baseline, no mesh) | `terraform/modules/cilium/` |

---

## Usage

Module documentation is automatically updated via `terraform-docs`. Run:
```bash
mise run doc:generate
```
to refresh module reference documentation.
