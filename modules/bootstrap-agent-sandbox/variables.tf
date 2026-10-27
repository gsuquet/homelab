# ─────────────────────────────────────────────
# Release identity
# ─────────────────────────────────────────────
variable "release_name" {
  description = "Name of the Helm release."
  type        = string
  default     = "agent-sandbox"
}

variable "namespace" {
  description = "Namespace to install the agent-sandbox controller into."
  type        = string
  default     = "agent-sandbox-system"
}

variable "create_namespace" {
  description = "Whether to create the Kubernetes namespace if it does not already exist."
  type        = bool
  default     = true
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

# ─────────────────────────────────────────────
# Controller & Image Settings
# ─────────────────────────────────────────────
variable "image_tag" {
  description = "Image tag for the agent-sandbox-controller (registry.k8s.io/agent-sandbox/agent-sandbox-controller)."
  type        = string
  default     = "v1.0.3"
}

variable "replica_count" {
  description = "Number of controller replicas to deploy."
  type        = number
  default     = 1
}

variable "enable_extensions" {
  description = "Enable agent-sandbox extensions (SandboxTemplate, SandboxWarmPool, and SandboxClaim controllers)."
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────
# Observability
# ─────────────────────────────────────────────
variable "prometheus_servicemonitor_enabled" {
  description = "Enable Prometheus Operator ServiceMonitor resource for scraping agent-sandbox metrics."
  type        = bool
  default     = false
}
