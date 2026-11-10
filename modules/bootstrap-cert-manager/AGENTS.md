# AGENTS.md — bootstrap-cert-manager Terraform module

## Purpose

Installs [cert-manager](https://cert-manager.io/) via its official Helm chart,
providing automated TLS certificate management, ACME challenge solving (Gateway API HTTP-01
and Cloudflare DNS-01), and out-of-the-box ClusterIssuer resources.

## Key design decisions

- **OCI chart repository.** The chart is pulled directly from the official OCI
  registry (`oci://quay.io/jetstack/charts/cert-manager`) rather than a classic Helm repo
  — no `helm repo add` needed, and OCI artifacts are cosign-signed.
- **`cert-manager` namespace by default.** Defaults to dedicated `cert-manager` namespace
  managed via `kubernetes_namespace_v1` (`create_namespace = true`).
- **CRD lifecycle in Helm.** `crds.enabled = true` and `crds.keep = true` make sure that
  cert-manager CRDs are properly deployed on install and preserved on release uninstall
  to avoid cascading garbage collection of certificates and keys.
- **Gateway API first-class integration.** With clusters moving to Gateway API (e.g. Cilium
  Gateway API), `--enable-gateway-api` is passed to the controller and the HTTP-01 solver
  references a `Gateway` via `gatewayHTTPRoute` by default.
- **ClusterIssuers via `kubectl_manifest`.** Built-in ClusterIssuers (`selfsigned`,
  `letsencrypt-staging`, and `letsencrypt-prod`) are managed as `kubectl_manifest` resources
  using the `alekc/kubectl` provider with `depends_on = [helm_release.cert_manager]`. This avoids
  plan-time CRD discovery failures (unlike `kubernetes_manifest`) while decoupling custom
  resources from Helm values.
- **Template-driven values with static uppercase placeholders.** The upstream
  values file (`templates/cert-manager-values.yaml.tftpl`) uses static uppercase
  placeholders (`${VARIABLE_NAME}`) rendered via `templatefile()` in
  `main.tf`. All conditionals and defaults are computed in `locals.tf`
  under `local.cert_manager_values`.
- **Cloudflare DNS-01 integration.** The module takes the name of a Secret
  (`cloudflare_api_token_secret_name`, key `api-token`). It never takes the token and never
  creates the Secret: External Secrets Operator writes it from a seed, so the token is not in a
  Terraform variable, plan or state. Refer to [Secrets](../../docs/reference/secrets.md).
  Optional DNS zone selectors route wildcard/internal domains to Cloudflare while standard
  public endpoints use Gateway API.
  - **Where the Secret must be.** A `ClusterIssuer` looks up its Secrets in the cluster resource
    namespace ([cert-manager: Cluster Resource Namespace](https://cert-manager.io/docs/configuration/#cluster-resource-namespace)).
    The values template leaves `clusterResourceNamespace` empty, so that namespace is the
    controller namespace: the module input `namespace` (default `cert-manager`). The
    `ExternalSecret` must write the Secret there, with the key `api-token`. If a change sets
    `clusterResourceNamespace`, the Secret must move with it.
  - **Before ESO writes the Secret.** The ClusterIssuers use the token only to present a DNS-01
    challenge, not to register the ACME account. So `terraform apply` succeeds and the issuers
    become Ready without the Secret; each DNS-01 challenge fails until the Secret exists, and
    cert-manager tries it again. The retry of a failed presentation is not in the cert-manager
    docs ([ACME Orders and Challenges](https://cert-manager.io/docs/concepts/acme-orders-challenges/#challenge-lifecycle)
    covers only the self check) and is not tested here. The module creates the namespace when
    `create_namespace = true`, so the `ExternalSecret` syncs after `instance:up`.

## Variables that require attention

| Variable | Notes |
|---|---|
| `acme_email` | Required for Let's Encrypt registration and renewal alerts when Let's Encrypt issuers are enabled. |
| `enable_gateway_api_solver` | Directs HTTP-01 ACME challenge solving through Gateway API HTTPRoutes targeting `gateway_name`. |
| `gateway_name` | Name of the Gateway resource (default: `cilium`). |
| `enable_cloudflare_dns01_solver` | Enables DNS-01 challenge solver using Cloudflare API token. |
| `cloudflare_api_token_secret_name` | Name of the Secret that ESO writes in the module `namespace` (the cluster resource namespace), with the key `api-token`. The ClusterIssuers refer to it. Without it, DNS-01 challenges fail until it exists. |
| `cloudflare_dns01_zones` | Specific DNS zones targeted by Cloudflare DNS-01 solver. |
| `prometheus_servicemonitor_enabled` | Deploys Prometheus Operator `ServiceMonitor` for cert-manager metrics. |

## Outputs consumed by downstream modules

`release_name`, `namespace`, `selfsigned_issuer_name`, `letsencrypt_staging_issuer_name`,
and `letsencrypt_prod_issuer_name` give references for downstream modules or Helm releases
that reference ClusterIssuers in Certificate resources or Gateway / Ingress annotations.

## Modifying this module

- **`cluster-issuers.tf`** — `kubectl_manifest` resources provisioning the ClusterIssuers using `templates/cluster-issuer-*.yaml.tftpl`.
- **`templates/cluster-issuer-*.yaml.tftpl`** — GitOps-style Kubernetes manifests for `selfsigned`, `letsencrypt-staging`, and `letsencrypt-prod` ClusterIssuers.
- **`locals.tf`** — computed static uppercase template values (`local.cert_manager_values`) and template variables for ClusterIssuer manifests.
- **`templates/cert-manager-values.yaml.tftpl`** — upstream values file with static
  `${VARIABLE_NAME}` placeholders.
- **`variables.tf`** — defined module variables with validations and defaults.
- **`main.tf`** — single `helm_release.cert_manager` resource rendering values
  via `templatefile()` with `local.cert_manager_values`.
- **`namespace.tf`** — conditional `kubernetes_namespace_v1` on `create_namespace`.
- **`outputs.tf`** — expose names, statuses, and issuer references.

## Do not

- Add a variable that takes a secret value, or a `kubernetes_secret_v1` with `data`. A secret
  goes through a seed namespace and ESO; the module takes only the name of the Secret.
- Replace `kubectl_manifest` with `kubernetes_manifest` without accounting for plan-time
  CRD discovery issues on fresh clusters.
- Remove the digest/version pin on chart installation or default to `latest`.
- Remove `crds.keep: true` unless you explicitly want cascading deletion of all certificates
  upon uninstall.
