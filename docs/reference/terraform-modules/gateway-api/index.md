# gateway-api

Deploys official Kubernetes [Gateway API](https://gateway-api.sigs.k8s.io/) CustomResourceDefinitions (`gateway.networking.k8s.io`) using official release manifests and the `kubectl` provider.
See [AGENTS.md](AGENTS.md) for key architectural and design decisions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.15.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | 2.2.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 2.2.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_channel"></a> [channel](#input\_channel) | Gateway API release channel to install: 'standard' or 'experimental'. | `string` | `"standard"` | no |
| <a name="input_force_conflicts"></a> [force\_conflicts](#input\_force\_conflicts) | Force overwrite field ownership conflicts when server\_side\_apply is enabled. | `bool` | `true` | no |
| <a name="input_server_side_apply"></a> [server\_side\_apply](#input\_server\_side\_apply) | Apply CRD manifests using Kubernetes Server-Side Apply to avoid client-side 256KB annotation limits. | `bool` | `true` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Wait for the CRD resources to reach established state before considering the apply complete. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_channel"></a> [channel](#output\_channel) | The installed Gateway API release channel ('standard' or 'experimental'). |
| <a name="output_crd_count"></a> [crd\_count](#output\_crd\_count) | Total number of CRD documents applied. |
| <a name="output_crd_names"></a> [crd\_names](#output\_crd\_names) | List of CRD resource identifiers deployed by this module. |
| <a name="output_version"></a> [version](#output\_version) | The version of Gateway API CRD manifests bundled with this module. |
<!-- END_TF_DOCS -->
