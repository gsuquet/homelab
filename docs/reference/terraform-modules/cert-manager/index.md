# cert-manager

Installs [cert-manager](https://cert-manager.io/) via its official Helm chart, providing automated TLS certificate management, Gateway API HTTP-01 and Cloudflare DNS-01 challenge solving, and pre-configured ClusterIssuers.
See [AGENTS.md](AGENTS.md) for key architectural and design decisions.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | > 1.15.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 3.1.1 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | 2.2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 3.1.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 2.2.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.1.0 |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_acme_custom_solvers"></a> [acme\_custom\_solvers](#input\_acme\_custom\_solvers) | Additional custom challenge solvers to include in Let's Encrypt ClusterIssuers. | `any` | `[]` | no |
| <a name="input_acme_email"></a> [acme\_email](#input\_acme\_email) | Email address used for Let's Encrypt ACME registration and certificate expiry notifications. | `string` | `""` | no |
| <a name="input_cainjector_replicas"></a> [cainjector\_replicas](#input\_cainjector\_replicas) | Number of cert-manager cainjector replicas to deploy. | `number` | `1` | no |
| <a name="input_chart_digest"></a> [chart\_digest](#input\_chart\_digest) | Digest of the cert-manager chart (oci://quay.io/jetstack/charts/cert-manager) to install. Pinned for reproducibility — bump deliberately. | `string` | `""` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | Version of the cert-manager chart (oci://quay.io/jetstack/charts/cert-manager) to install. Pinned for reproducibility — bump deliberately. | `string` | `"v1.21.2"` | no |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token with Zone:DNS:Edit permissions. If non-empty and create\_cloudflare\_secret is true, a Secret is created automatically. | `string` | `""` | no |
| <a name="input_cloudflare_api_token_secret_name"></a> [cloudflare\_api\_token\_secret\_name](#input\_cloudflare\_api\_token\_secret\_name) | Name of the Kubernetes Secret containing the Cloudflare API token (key: 'api-token'). | `string` | `"cloudflare-api-token-secret"` | no |
| <a name="input_cloudflare_dns01_domains"></a> [cloudflare\_dns01\_domains](#input\_cloudflare\_dns01\_domains) | List of specific DNS domain names to route to Cloudflare DNS-01 solver (e.g. ['*.example.com']). | `list(string)` | `[]` | no |
| <a name="input_cloudflare_dns01_zones"></a> [cloudflare\_dns01\_zones](#input\_cloudflare\_dns01\_zones) | List of DNS zones to route to Cloudflare DNS-01 solver (e.g. ['example.com']). | `list(string)` | `[]` | no |
| <a name="input_common_labels"></a> [common\_labels](#input\_common\_labels) | Labels applied to every cert-manager resource (chart's global.commonLabels value). | `map(string)` | `{}` | no |
| <a name="input_controller_extra_args"></a> [controller\_extra\_args](#input\_controller\_extra\_args) | Additional CLI flags to pass to the cert-manager controller binary. | `list(string)` | `[]` | no |
| <a name="input_controller_replicas"></a> [controller\_replicas](#input\_controller\_replicas) | Number of cert-manager controller replicas to deploy. | `number` | `1` | no |
| <a name="input_crds_enabled"></a> [crds\_enabled](#input\_crds\_enabled) | Install cert-manager CustomResourceDefinitions as part of the Helm release. | `bool` | `true` | no |
| <a name="input_crds_keep"></a> [crds\_keep](#input\_crds\_keep) | Add the 'helm.sh/resource-policy: keep' annotation to CRDs to prevent accidental deletion upon release uninstall. | `bool` | `true` | no |
| <a name="input_create_cloudflare_secret"></a> [create\_cloudflare\_secret](#input\_create\_cloudflare\_secret) | Whether to create the Kubernetes Secret when cloudflare\_api\_token is provided. | `bool` | `true` | no |
| <a name="input_create_namespace"></a> [create\_namespace](#input\_create\_namespace) | Whether to create the Kubernetes namespace if it does not already exist. | `bool` | `true` | no |
| <a name="input_enable_cloudflare_dns01_solver"></a> [enable\_cloudflare\_dns01\_solver](#input\_enable\_cloudflare\_dns01\_solver) | Include Cloudflare DNS-01 challenge solver in Let's Encrypt ClusterIssuers. | `bool` | `false` | no |
| <a name="input_enable_gateway_api"></a> [enable\_gateway\_api](#input\_enable\_gateway\_api) | Enable Gateway API support in cert-manager controller (--enable-gateway-api). | `bool` | `true` | no |
| <a name="input_enable_gateway_api_solver"></a> [enable\_gateway\_api\_solver](#input\_enable\_gateway\_api\_solver) | Include Gateway API HTTPRoute solver in Let's Encrypt ClusterIssuers. | `bool` | `true` | no |
| <a name="input_enable_letsencrypt_prod_issuer"></a> [enable\_letsencrypt\_prod\_issuer](#input\_enable\_letsencrypt\_prod\_issuer) | Provision a Let's Encrypt Production ClusterIssuer named 'letsencrypt-prod'. | `bool` | `true` | no |
| <a name="input_enable_letsencrypt_staging_issuer"></a> [enable\_letsencrypt\_staging\_issuer](#input\_enable\_letsencrypt\_staging\_issuer) | Provision a Let's Encrypt Staging ClusterIssuer named 'letsencrypt-staging'. | `bool` | `true` | no |
| <a name="input_enable_selfsigned_issuer"></a> [enable\_selfsigned\_issuer](#input\_enable\_selfsigned\_issuer) | Provision a self-signed ClusterIssuer named 'selfsigned'. | `bool` | `true` | no |
| <a name="input_gateway_group"></a> [gateway\_group](#input\_gateway\_group) | API group of the Gateway resource for parentRefs. | `string` | `"gateway.networking.k8s.io"` | no |
| <a name="input_gateway_kind"></a> [gateway\_kind](#input\_gateway\_kind) | Kind of the Gateway resource for parentRefs. | `string` | `"Gateway"` | no |
| <a name="input_gateway_name"></a> [gateway\_name](#input\_gateway\_name) | Name of the Gateway resource used by Gateway API HTTPRoute solver. | `string` | `"cilium"` | no |
| <a name="input_gateway_namespace"></a> [gateway\_namespace](#input\_gateway\_namespace) | Namespace of the Gateway resource used by Gateway API HTTPRoute solver. If empty, omitted from parentRefs. | `string` | `""` | no |
| <a name="input_leader_election_namespace"></a> [leader\_election\_namespace](#input\_leader\_election\_namespace) | Override the namespace used for the leader election lease. | `string` | `"kube-system"` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | Verbosity level for cert-manager logging (0 to 6, with 6 being the most verbose). | `number` | `2` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to install cert-manager into. | `string` | `"cert-manager"` | no |
| <a name="input_prometheus_servicemonitor_enabled"></a> [prometheus\_servicemonitor\_enabled](#input\_prometheus\_servicemonitor\_enabled) | Enable Prometheus ServiceMonitor resource for cert-manager metrics. | `bool` | `false` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Name of the Helm release. | `string` | `"cert-manager"` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Time in seconds to wait for the release to be ready. | `number` | `600` | no |
| <a name="input_wait"></a> [wait](#input\_wait) | Wait for the release to reach a ready state before Terraform considers the apply successful. | `bool` | `true` | no |
| <a name="input_webhook_replicas"></a> [webhook\_replicas](#input\_webhook\_replicas) | Number of cert-manager webhook replicas to deploy. | `number` | `1` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_crds_enabled"></a> [crds\_enabled](#output\_crds\_enabled) | Whether cert-manager CRDs are managed by this module. |
| <a name="output_enable_gateway_api"></a> [enable\_gateway\_api](#output\_enable\_gateway\_api) | Whether Gateway API support is enabled in cert-manager. |
| <a name="output_letsencrypt_prod_issuer_name"></a> [letsencrypt\_prod\_issuer\_name](#output\_letsencrypt\_prod\_issuer\_name) | Name of the Let's Encrypt Production ClusterIssuer if enabled. |
| <a name="output_letsencrypt_staging_issuer_name"></a> [letsencrypt\_staging\_issuer\_name](#output\_letsencrypt\_staging\_issuer\_name) | Name of the Let's Encrypt Staging ClusterIssuer if enabled. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace cert-manager was installed into. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Name of the Helm release. |
| <a name="output_release_status"></a> [release\_status](#output\_release\_status) | Status of the Helm release, as reported by Helm. |
| <a name="output_selfsigned_issuer_name"></a> [selfsigned\_issuer\_name](#output\_selfsigned\_issuer\_name) | Name of the self-signed ClusterIssuer if enabled. |
<!-- END_TF_DOCS -->
