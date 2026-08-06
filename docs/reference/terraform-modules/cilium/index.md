# cilium

Installs Cilium as the cluster's CNI via its official Helm chart — the pure
networking baseline for the
[Zero Trust, Shadow Traffic & Chaos Engineering Lab](../../../docs/explanation/zero-trust-chaos-lab.md).
See [AGENTS.md](AGENTS.md) for design decisions, especially why Hubble
relay/UI are variables on this module rather than a separate Helm release.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.15.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 3.1.1 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 3.1.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.1.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_chart_digest"></a> [chart\_digest](#input\_chart\_digest) | Digest of the cilium/cilium chart (oci://quay.io/cilium/charts/cilium) to install. Pinned for reproducibility — bump deliberately. | `string` | `""` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of the cilium/cilium chart (oci://quay.io/cilium/charts/cilium) to install. Pinned for reproducibility — bump deliberately. | `string` | `"1.20.0"` | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ID of the cluster. 0 means it's the main cluster. It must be between 0 and 255. | `number` | `0` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster. It must contain at most 32 characters; It must begin and end with a lower case alphanumeric character; It may contain lower case alphanumeric characters and dashes between. | `string` | n/a | yes |
| <a name="input_cluster_type"></a> [cluster\_type](#input\_cluster\_type) | Target platform: 'kind' (local), 'gke', 'eks', 'aks', or 'generic' (no platform-specific overrides — use extra\_values instead). | `string` | `"kind"` | no |
| <a name="input_common_labels"></a> [common\_labels](#input\_common\_labels) | Labels applied to every Cilium resource (chart's commonLabels value). | `map(string)` | `{}` | no |
| <a name="input_eks_eni_enabled"></a> [eks\_eni\_enabled](#input\_eks\_eni\_enabled) | EKS only: use AWS ENI mode (eni.enabled) instead of overlay routing, per Cilium's EKS quickstart. Ignored unless cluster\_type = "eks". | `bool` | `true` | no |
| <a name="input_encryption_enabled"></a> [encryption\_enabled](#input\_encryption\_enabled) | Enable transparent pod-to-pod traffic encryption. Core to the zero trust pillar of the lab. | `bool` | `true` | no |
| <a name="input_encryption_type"></a> [encryption\_type](#input\_encryption\_type) | Encryption backend when encryption\_enabled is true: 'wireguard' (simpler, generally faster) or 'ipsec'. | `string` | `"wireguard"` | no |
| <a name="input_extra_values"></a> [extra\_values](#input\_extra\_values) | Additional raw Helm values (YAML strings), applied after the computed base values. Use this for scenario-specific configuration this module doesn't have a dedicated variable for — e.g. settings needed to pair Cilium with Istio ambient mode in a later phase — instead of growing this module's variable list for every scenario. | `list(string)` | `[]` | no |
| <a name="input_gke_cni_bin_path"></a> [gke\_cni\_bin\_path](#input\_gke\_cni\_bin\_path) | GKE only: path to the CNI binary directory on GKE nodes, per Cilium's GKE quickstart. Ignored unless cluster\_type = "gke". | `string` | `"/home/kubernetes/bin"` | no |
| <a name="input_gke_node_init_enabled"></a> [gke\_node\_init\_enabled](#input\_gke\_node\_init\_enabled) | GKE only: enable nodeinit (reconfigureKubelet, removeCbrBridge) as recommended by Cilium's GKE quickstart. Ignored unless cluster\_type = "gke". | `bool` | `true` | no |
| <a name="input_hubble_enabled"></a> [hubble\_enabled](#input\_hubble\_enabled) | Enable Hubble's flow-visibility component in the Cilium agent. Required before hubble\_relay\_enabled/hubble\_ui\_enabled can do anything. | `bool` | `true` | no |
| <a name="input_hubble_relay_enabled"></a> [hubble\_relay\_enabled](#input\_hubble\_relay\_enabled) | Enable the Hubble Relay deployment. Defaults to false: relay/UI are part of the same Helm chart/release as Cilium itself (see AGENTS.md for why this can't be a second, independent Helm release), so the hubble module flips this on rather than installing anything of its own. | `bool` | `false` | no |
| <a name="input_hubble_ui_enabled"></a> [hubble\_ui\_enabled](#input\_hubble\_ui\_enabled) | Enable the Hubble UI deployment. Same caveat as hubble\_relay\_enabled. | `bool` | `false` | no |
| <a name="input_ipv4_native_routing_cidr"></a> [ipv4\_native\_routing\_cidr](#input\_ipv4\_native\_routing\_cidr) | Pod CIDR for native routing mode. Leave empty to use the chart default (encapsulation/VXLAN mode) — set this to match the cluster's pod\_subnet when native routing is desired. | `string` | `""` | no |
| <a name="input_k8s_service_host"></a> [k8s\_service\_host](#input\_k8s\_service\_host) | Kubernetes API server address, required when kube\_proxy\_replacement is true and the API server isn't otherwise reachable via the in-cluster service (e.g. on kind). Leave empty to let the chart use its own default detection. | `string` | `""` | no |
| <a name="input_k8s_service_port"></a> [k8s\_service\_port](#input\_k8s\_service\_port) | Kubernetes API server port, paired with k8s\_service\_host. Leave empty to let the chart use its own default detection. | `string` | `""` | no |
| <a name="input_kube_proxy_replacement"></a> [kube\_proxy\_replacement](#input\_kube\_proxy\_replacement) | Replace kube-proxy with Cilium's eBPF datapath. Recommended for the zero trust lab (fewer moving parts, faster L3-L4 enforcement). | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to install Cilium into. Defaults to kube-system, which already exists on every cluster and is therefore not created by this module. Any other value is created automatically. | `string` | `"kube-system"` | no |
| <a name="input_policy_enforcement_mode"></a> [policy\_enforcement\_mode](#input\_policy\_enforcement\_mode) | Cilium network policy enforcement mode: 'default' (deny only for endpoints selected by a policy), 'always' (deny-by-default for every endpoint), or 'never'. The zero trust lab scenarios assume 'default' plus explicit CiliumNetworkPolicy resources per workload. | `string` | `"default"` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Name of the Helm release. | `string` | `"cilium"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Time in seconds to wait for the release to be ready. | `number` | `600` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Wait for the release to reach a ready state before Terraform considers the apply successful. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_hubble_relay_enabled"></a> [hubble\_relay\_enabled](#output\_hubble\_relay\_enabled) | Whether Hubble Relay is enabled on this release. Consumed by the hubble module to know whether it still needs to flip this on. |
| <a name="output_hubble_ui_enabled"></a> [hubble\_ui\_enabled](#output\_hubble\_ui\_enabled) | Whether the Hubble UI is enabled on this release. Consumed by the hubble module to know whether it still needs to flip this on. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace Cilium was installed into. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Name of the Helm release. |
| <a name="output_release_status"></a> [release\_status](#output\_release\_status) | Status of the Helm release, as reported by Helm. |
<!-- END_TF_DOCS -->
