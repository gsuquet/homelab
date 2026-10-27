# ─────────────────────────────────────────────
# Gateway API Configuration
# ─────────────────────────────────────────────
variable "channel" {
  description = "Gateway API release channel to install: 'standard' or 'experimental'."
  type        = string
  default     = "standard"

  validation {
    error_message = "Channel must be either 'standard' or 'experimental'."
    condition     = contains(["standard", "experimental"], var.channel)
  }
}

variable "server_side_apply" {
  description = "Apply CRD manifests using Kubernetes Server-Side Apply to avoid client-side 256KB annotation limits."
  type        = bool
  default     = true
}

variable "force_conflicts" {
  description = "Force overwrite field ownership conflicts when server_side_apply is enabled."
  type        = bool
  default     = true
}

variable "wait" {
  description = "Wait for the CRD resources to reach established state before considering the apply complete."
  type        = bool
  default     = true
}
