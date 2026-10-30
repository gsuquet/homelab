# bootstrap-argocd

Installs [Argo CD](https://argo-cd.readthedocs.io/) one time from the rendered manifests in `gitops/clusters/<cluster>/rendered/argocd/`. After the bootstrap, Argo CD syncs the same folder from Git, manages itself and makes the Applications of the other components.
Refer to [AGENTS.md](AGENTS.md) for the design decisions.

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
| <a name="input_application"></a> [application](#input\_application) | Name of the Argo CD Application that syncs manifests\_dir. Terraform applies this Application and no other: Argo CD makes the other Applications in the order of their sync waves. | `string` | `"argocd"` | no |
| <a name="input_force_conflicts"></a> [force\_conflicts](#input\_force\_conflicts) | Take the ownership of fields that another field manager owns, for example after a manual kubectl apply. | `bool` | `true` | no |
| <a name="input_manifests_dir"></a> [manifests\_dir](#input\_manifests\_dir) | Folder with the rendered Argo CD manifests of the cluster: gitops/clusters/<cluster>/rendered/argocd. Argo CD syncs the same folder after the bootstrap. | `string` | n/a | yes |
| <a name="input_wait_for_rollout"></a> [wait\_for\_rollout](#input\_wait\_for\_rollout) | Wait until the Argo CD Deployments and StatefulSets are ready before the apply completes. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_manifest_keys"></a> [manifest\_keys](#output\_manifest\_keys) | Keys (<kind>/<namespace>/<name>) of the resources that the bootstrap applied. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace of Argo CD, from the Namespace manifest in manifests\_dir. |
<!-- END_TF_DOCS -->
