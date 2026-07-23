<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.15.0 |
| <a name="requirement_kind"></a> [kind](#requirement\_kind) | 0.11.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_kind"></a> [kind](#provider\_kind) | 0.11.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_api_server_address"></a> [api\_server\_address](#input\_api\_server\_address) | Address on which the API server will listen. Leave empty to use the Kind default (127.0.0.1). | `string` | `""` | no |
| <a name="input_api_server_port"></a> [api\_server\_port](#input\_api\_server\_port) | Port on which the API server will listen. Set to 0 to use a random available port (Kind default). | `number` | `0` | no |
| <a name="input_control_plane_count"></a> [control\_plane\_count](#input\_control\_plane\_count) | Number of control-plane nodes. Must be 1 for a standard cluster (HA control-plane is experimental in Kind). | `number` | `1` | no |
| <a name="input_control_plane_kubeadm_config_patches"></a> [control\_plane\_kubeadm\_config\_patches](#input\_control\_plane\_kubeadm\_config\_patches) | List of kubeadm InitConfiguration/ClusterConfiguration YAML patches applied to each control-plane node. Useful for adding node labels, taints, or kubelet arguments. | `list(string)` | `[]` | no |
| <a name="input_disable_default_cni"></a> [disable\_default\_cni](#input\_disable\_default\_cni) | Disable the default CNI plugin (kindnet). Set to true when installing a custom CNI such as Cilium or Calico. | `bool` | `false` | no |
| <a name="input_extra_port_mappings"></a> [extra\_port\_mappings](#input\_extra\_port\_mappings) | Extra port mappings to expose from the control-plane node to the host. Commonly used to expose an ingress controller (e.g., host\_port=80 → container\_port=80). | <pre>list(object({<br/>    container_port = number<br/>    host_port      = number<br/>    protocol       = optional(string, "TCP")<br/>  }))</pre> | `[]` | no |
| <a name="input_kubeconfig_path"></a> [kubeconfig\_path](#input\_kubeconfig\_path) | Path where the kubeconfig will be written. Defaults to ~/.kube/kind-<name> to avoid polluting the default kubeconfig. | `string` | `""` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the Kind cluster. Must be lowercase alphanumeric and hyphens only. | `string` | n/a | yes |
| <a name="input_node_image"></a> [node\_image](#input\_node\_image) | Base image name for Kind nodes (without tag or digest). | `string` | `"kindest/node"` | no |
| <a name="input_node_image_digest"></a> [node\_image\_digest](#input\_node\_image\_digest) | SHA256 digest of the node image for reproducible, tamper-resistant builds. Find the digest for a given release at https://github.com/kubernetes-sigs/kind/releases. | `string` | `"3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"` | no |
| <a name="input_node_image_tag"></a> [node\_image\_tag](#input\_node\_image\_tag) | Kubernetes version tag for the node image (e.g. v1.36.1). | `string` | `"v1.36.1"` | no |
| <a name="input_pod_subnet"></a> [pod\_subnet](#input\_pod\_subnet) | CIDR range for pod IPs. Leave empty to use the Kind default (10.244.0.0/16). Set to match your production cluster for staging environments. | `string` | `""` | no |
| <a name="input_service_subnet"></a> [service\_subnet](#input\_service\_subnet) | CIDR range for service IPs. Leave empty to use the Kind default (10.96.0.0/12). Set to match your production cluster for staging environments. | `string` | `""` | no |
| <a name="input_worker_count"></a> [worker\_count](#input\_worker\_count) | Number of worker nodes. | `number` | `2` | no |
| <a name="input_worker_kubeadm_config_patches"></a> [worker\_kubeadm\_config\_patches](#input\_worker\_kubeadm\_config\_patches) | List of kubeadm JoinConfiguration YAML patches applied to each worker node. Useful for adding node labels or kubelet arguments. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_client_certificate"></a> [client\_certificate](#output\_client\_certificate) | Client certificate for authenticating to the cluster. |
| <a name="output_client_key"></a> [client\_key](#output\_client\_key) | Client key for authenticating to the cluster. |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Cluster CA certificate for verifying the API server's TLS certificate. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | URL of the Kubernetes API server. |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Full kubeconfig content as a string. Use this to configure the kubernetes/helm providers without relying on a file on disk. |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Absolute path to the written kubeconfig file. |
| <a name="output_name"></a> [name](#output\_name) | Name of the Kind cluster. |
<!-- END_TF_DOCS -->