# agent-sandbox

Installs the Kubernetes SIG Apps [agent-sandbox](https://github.com/kubernetes-sigs/agent-sandbox) controller and CustomResourceDefinitions via Helm, providing declarative AI agent workload isolation and sandbox lifecycle management.
See [AGENTS.md](AGENTS.md) for key architectural and design decisions.

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
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Whether to create the Kubernetes namespace if it does not already exist. | `bool` | `true` | no |
| <a name="input_enable_extensions"></a> [enable\_extensions](#input\_enable\_extensions) | Enable agent-sandbox extensions (SandboxTemplate, SandboxWarmPool, and SandboxClaim controllers). | `bool` | `true` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | Image tag for the agent-sandbox-controller (registry.k8s.io/agent-sandbox/agent-sandbox-controller). | `string` | `"v1.0.3"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to install the agent-sandbox controller into. | `string` | `"agent-sandbox-system"` | no |
| <a name="input_prometheus_servicemonitor_enabled"></a> [prometheus\_servicemonitor\_enabled](#input\_prometheus\_servicemonitor\_enabled) | Enable Prometheus Operator ServiceMonitor resource for scraping agent-sandbox metrics. | `bool` | `false` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Name of the Helm release. | `string` | `"agent-sandbox"` | no |
| <a name="input_replica_count"></a> [replica\_count](#input\_replica\_count) | Number of controller replicas to deploy. | `number` | `1` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Time in seconds to wait for the release to be ready. | `number` | `600` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Wait for the release to reach a ready state before Terraform considers the apply successful. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_extensions_enabled"></a> [extensions\_enabled](#output\_extensions\_enabled) | Whether agent-sandbox extensions (SandboxTemplate, SandboxWarmPool, SandboxClaim) are enabled. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace the agent-sandbox controller was installed into. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Name of the Helm release. |
| <a name="output_release_status"></a> [release\_status](#output\_release\_status) | Status of the Helm release, as reported by Helm. |
| <a name="output_version"></a> [version](#output\_version) | Image version tag of the agent-sandbox controller deployed. |
<!-- END_TF_DOCS -->
