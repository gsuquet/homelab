# ─────────────────────────────────────────────
# Release identity
# ─────────────────────────────────────────────
variable "release_name" {
  description = "Name of the Helm release."
  type        = string
  default     = "cert-manager"
}

variable "namespace" {
  description = "Namespace to install cert-manager into."
  type        = string
  default     = "cert-manager"
}

variable "create_namespace" {
  description = "Whether to create the Kubernetes namespace if it does not already exist."
  type        = bool
  default     = true
}

variable "chart_digest" {
  description = "Digest of the cert-manager chart (oci://quay.io/jetstack/charts/cert-manager) to install. Pinned for reproducibility — bump deliberately."
  type        = string
  default     = ""
}

variable "chart_version" {
  description = "Version of the cert-manager chart (oci://quay.io/jetstack/charts/cert-manager) to install. Pinned for reproducibility — bump deliberately."
  type        = string
  default     = "v1.21.2"
}

variable "wait" {
  description = "Wait for the release to reach a ready state before Terraform considers the apply successful."
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Time in seconds to wait for the release to be ready."
  type        = number
  default     = 600
}

variable "common_labels" {
  description = "Labels applied to every cert-manager resource (chart's global.commonLabels value)."
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────
# Core settings
# ─────────────────────────────────────────────
variable "log_level" {
  description = "Verbosity level for cert-manager logging (0 to 6, with 6 being the most verbose)."
  type        = number
  default     = 2

  validation {
    error_message = "log_level must be an integer between 0 and 6."
    condition     = var.log_level >= 0 && var.log_level <= 6
  }
}

variable "leader_election_namespace" {
  description = "Override the namespace used for the leader election lease."
  type        = string
  default     = "kube-system"
}

variable "crds_enabled" {
  description = "Install cert-manager CustomResourceDefinitions as part of the Helm release."
  type        = bool
  default     = true
}

variable "crds_keep" {
  description = "Add the 'helm.sh/resource-policy: keep' annotation to CRDs to prevent accidental deletion upon release uninstall."
  type        = bool
  default     = true
}

variable "controller_replicas" {
  description = "Number of cert-manager controller replicas to deploy."
  type        = number
  default     = 1
}

variable "webhook_replicas" {
  description = "Number of cert-manager webhook replicas to deploy."
  type        = number
  default     = 1
}

variable "cainjector_replicas" {
  description = "Number of cert-manager cainjector replicas to deploy."
  type        = number
  default     = 1
}

variable "controller_extra_args" {
  description = "Additional CLI flags to pass to the cert-manager controller binary."
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────
# Gateway API
# ─────────────────────────────────────────────
variable "enable_gateway_api" {
  description = "Enable Gateway API support in cert-manager controller (--enable-gateway-api)."
  type        = bool
  default     = true
}

variable "enable_gateway_api_solver" {
  description = "Include Gateway API HTTPRoute solver in Let's Encrypt ClusterIssuers."
  type        = bool
  default     = true
}

variable "gateway_name" {
  description = "Name of the Gateway resource used by Gateway API HTTPRoute solver."
  type        = string
  default     = "cilium"
}

variable "gateway_namespace" {
  description = "Namespace of the Gateway resource used by Gateway API HTTPRoute solver. If empty, omitted from parentRefs."
  type        = string
  default     = ""
}

variable "gateway_kind" {
  description = "Kind of the Gateway resource for parentRefs."
  type        = string
  default     = "Gateway"
}

variable "gateway_group" {
  description = "API group of the Gateway resource for parentRefs."
  type        = string
  default     = "gateway.networking.k8s.io"
}

# ─────────────────────────────────────────────
# Cloudflare DNS-01
# ─────────────────────────────────────────────
variable "enable_cloudflare_dns01_solver" {
  description = "Include Cloudflare DNS-01 challenge solver in Let's Encrypt ClusterIssuers."
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permissions. If non-empty and create_cloudflare_secret is true, a Secret is created automatically."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cloudflare_api_token_secret_name" {
  description = "Name of the Kubernetes Secret containing the Cloudflare API token (key: 'api-token')."
  type        = string
  default     = "cloudflare-api-token-secret"
}

variable "create_cloudflare_secret" {
  description = "Whether to create the Kubernetes Secret when cloudflare_api_token is provided."
  type        = bool
  default     = true
}

variable "cloudflare_dns01_zones" {
  description = "List of DNS zones to route to Cloudflare DNS-01 solver (e.g. ['example.com'])."
  type        = list(string)
  default     = []
}

variable "cloudflare_dns01_domains" {
  description = "List of specific DNS domain names to route to Cloudflare DNS-01 solver (e.g. ['*.example.com'])."
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────
# ClusterIssuers
# ─────────────────────────────────────────────
variable "enable_selfsigned_issuer" {
  description = "Provision a self-signed ClusterIssuer named 'selfsigned'."
  type        = bool
  default     = true
}

variable "enable_letsencrypt_staging_issuer" {
  description = "Provision a Let's Encrypt Staging ClusterIssuer named 'letsencrypt-staging'."
  type        = bool
  default     = true
}

variable "enable_letsencrypt_prod_issuer" {
  description = "Provision a Let's Encrypt Production ClusterIssuer named 'letsencrypt-prod'."
  type        = bool
  default     = true
}

variable "acme_email" {
  description = "Email address used for Let's Encrypt ACME registration and certificate expiry notifications."
  type        = string
  default     = ""
}

variable "acme_custom_solvers" {
  description = "Additional custom challenge solvers to include in Let's Encrypt ClusterIssuers."
  type        = any
  default     = []
}

# ─────────────────────────────────────────────
# Observability
# ─────────────────────────────────────────────
variable "prometheus_servicemonitor_enabled" {
  description = "Enable Prometheus ServiceMonitor resource for cert-manager metrics."
  type        = bool
  default     = false
}
