# bootstrap-coredns

Adds CoreDNS `rewrite` rules to the `coredns` ConfigMap in `kube-system`. Refer to [AGENTS.md](../../../../modules/bootstrap-coredns/AGENTS.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.15.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 3.1.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.1.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_config_map_name"></a> [config\_map\_name](#input\_config\_map\_name) | Name of the CoreDNS ConfigMap that kubeadm makes. | `string` | `"coredns"` | no |
| <a name="input_field_manager"></a> [field\_manager](#input\_field\_manager) | Field manager name that Terraform uses for the Corefile key. | `string` | `"terraform-bootstrap-coredns"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace of the coredns ConfigMap. kubeadm makes it in kube-system. | `string` | `"kube-system"` | no |
| <a name="input_rewrite_hostnames"></a> [rewrite\_hostnames](#input\_rewrite\_hostnames) | Host names that CoreDNS rewrites to rewrite\_target. Pods that resolve one of these names get the address of the target Service. An empty list adds no rule. | `list(string)` | n/a | yes |
| <a name="input_rewrite_target"></a> [rewrite\_target](#input\_rewrite\_target) | Fully qualified name of the Service that receives the rewritten names, for example gateway.example.svc.cluster.local. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_rewritten_hostnames"></a> [rewritten\_hostnames](#output\_rewritten\_hostnames) | Host names that the Corefile rewrites to the target Service. |
<!-- END_TF_DOCS -->
