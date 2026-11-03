# AGENTS.md: bootstrap-coredns Terraform module

## Purpose

Adds `rewrite` rules to the Corefile of the `coredns` ConfigMap in `kube-system`. A rule sends a host name to a Service of the cluster. Pods then use the same host name as a browser that reaches the Service through a port-forward.

## Design decisions

- **A module of its own.** CoreDNS is not part of Cilium (`bootstrap-cilium`), and `cluster-kind` is outside the scope of this change. The module is not specific to kind: kubeadm makes the same ConfigMap on other clusters.
- **Terraform, not Argo CD.** kubeadm makes the ConfigMap in `kube-system`, and Terraform owns `kube-system`. An `infrastructure` component that patches a kubeadm ConfigMap is rejected.
- **The module writes the whole Corefile.** A ConfigMap key is one string, so a patch of a part is not possible. The Corefile in `main.tf` is the kubeadm default of Kubernetes 1.37. Compare it with the live ConfigMap when the Kubernetes minor version changes.
- **`kubernetes_config_map_v1_data` with `force = true`.** It manages one key with its own field manager, and does not import the ConfigMap.
- **The `reload` plugin applies the change.** No pod restart.

## Inputs that need attention

| Variable | Notes |
|---|---|
| `rewrite_hostnames` | The names come from the OpenChoreo design. They depend on the OIDC issuer decision. |
| `rewrite_target` | The Service FQDN must exist, else the names resolve to NXDOMAIN. |

## Do not

- Add a rule before the Service that it points to is known.
- Edit the `coredns` ConfigMap by hand: Terraform replaces the key at the next apply.
