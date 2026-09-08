# ─────────────────────────────────────────────
# Release identity
# ─────────────────────────────────────────────
variable "release_name" {
  description = "Name of the Helm release."
  type        = string
  default     = "cilium"
}

variable "namespace" {
  description = "Namespace to install Cilium into. Defaults to kube-system, which already exists on every cluster and is therefore not created by this module. Any other value is created automatically."
  type        = string
  default     = "kube-system"
}

variable "chart_digest" {
  description = "Digest of the cilium/cilium chart (oci://quay.io/cilium/charts/cilium) to install. Pinned for reproducibility — bump deliberately."
  type        = string
  default     = ""
}

variable "chart_version" {
  description = "Version of the cilium/cilium chart (oci://quay.io/cilium/charts/cilium) to install. Pinned for reproducibility — bump deliberately."
  type        = string
  default     = "1.20.0"
}

# ─────────────────────────────────────────────
# Cluster
# ─────────────────────────────────────────────
variable "cluster_name" {
  description = "Name of the cluster. It must contain at most 32 characters; It must begin and end with a lower case alphanumeric character; It may contain lower case alphanumeric characters and dashes between."
  type        = string

  validation {
    error_message = "Name must be between 1 and 32 characters and contain only lowercase letters, numbers, and hyphens, and must start and end with a letter or number."
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 32 && can(regex("^[a-z0-9]", var.cluster_name)) && can(regex("[a-z0-9]$", var.cluster_name)) && can(regex("^[a-z0-9-]+$", var.cluster_name))
  }
}

variable "cluster_id" {
  description = "ID of the cluster. 0 means it's the main cluster. It must be between 0 and 255."
  type        = number
  default     = 0

  validation {
    error_message = "Cluster ID must be a value between 0 and 255."
    condition     = var.cluster_id >= 0 && var.cluster_id <= 255
  }
}

variable "common_labels" {
  description = "Labels applied to every Cilium resource (chart's commonLabels value)."
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────
# Platform
#
# Selects which of Cilium's per-platform Helm values from
# https://docs.cilium.io/en/stable/installation/k8s-install-helm/ (and the
# platform-specific quickstarts it links to) get applied on top of the base
# values file. Only one platform's overrides are ever applied at a time.
# ─────────────────────────────────────────────

variable "cluster_type" {
  description = "Target platform: 'kind' (local), 'gke', 'eks', 'aks', or 'generic'."
  type        = string
  default     = "kind"

  validation {
    condition     = contains(["kind", "gke", "eks", "aks", "generic"], var.cluster_type)
    error_message = "cluster_type must be one of: kind, gke, eks, aks, generic."
  }
}

variable "gke_node_init_enabled" {
  description = "GKE only: enable nodeinit (reconfigureKubelet, removeCbrBridge) as recommended by Cilium's GKE quickstart. Ignored unless cluster_type = \"gke\"."
  type        = bool
  default     = true
}

variable "gke_cni_bin_path" {
  description = "GKE only: path to the CNI binary directory on GKE nodes, per Cilium's GKE quickstart. Ignored unless cluster_type = \"gke\"."
  type        = string
  default     = "/home/kubernetes/bin"
}

variable "eks_eni_enabled" {
  description = "EKS only: use AWS ENI mode (eni.enabled) instead of overlay routing, per Cilium's EKS quickstart. Ignored unless cluster_type = \"eks\"."
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────
# Core networking
# ─────────────────────────────────────────────

variable "kube_proxy_replacement" {
  description = "Replace kube-proxy with Cilium's eBPF datapath (fewer moving parts, faster L3-L4 enforcement)."
  type        = bool
  default     = true
}

variable "k8s_service_host" {
  description = "Kubernetes API server address, required when kube_proxy_replacement is true and the API server isn't otherwise reachable via the in-cluster service (e.g. on kind). Leave empty to let the chart use its own default detection."
  type        = string
  default     = ""
}

variable "k8s_service_port" {
  description = "Kubernetes API server port, paired with k8s_service_host. Leave empty to let the chart use its own default detection."
  type        = string
  default     = ""
}

variable "ipv4_native_routing_cidr" {
  description = "Pod CIDR for native routing mode. Leave empty to use the chart default (encapsulation/VXLAN mode) — set this to match the cluster's pod_subnet when native routing is desired."
  type        = string
  default     = ""
}

variable "bandwidth_manager_enabled" {
  description = "Enable Cilium's bandwidth manager infrastructure for EDT (Earliest Departure Time) packet pacing and Pod bandwidth enforcement."
  type        = bool
  default     = true
}

variable "bandwidth_manager_bbr" {
  description = "Activate BBR TCP congestion control for Pods (requires bandwidth_manager_enabled = true)."
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────
# Policy enforcement & encryption
# ─────────────────────────────────────────────

variable "policy_enforcement_mode" {
  description = "Cilium network policy enforcement mode: 'default' (deny only for endpoints selected by a policy), 'always' (deny-by-default for every endpoint), or 'never'."
  type        = string
  default     = "default"

  validation {
    condition     = contains(["default", "always", "never"], var.policy_enforcement_mode)
    error_message = "policy_enforcement_mode must be one of: default, always, never."
  }
}

variable "encryption_enabled" {
  description = "Enable transparent pod-to-pod traffic encryption."
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption backend when encryption_enabled is true: 'wireguard' (simpler, generally faster) or 'ipsec'."
  type        = string
  default     = "wireguard"

  validation {
    condition     = contains(["wireguard", "ipsec"], var.encryption_type)
    error_message = "encryption_type must be one of: wireguard, ipsec."
  }
}

# ─────────────────────────────────────────────
# Hubble (base component only — relay/UI are toggled here but owned
# operationally by the dedicated hubble module; see AGENTS.md)
# ─────────────────────────────────────────────

variable "hubble_enabled" {
  description = "Enable Hubble's flow-visibility component in the Cilium agent. Required before hubble_relay_enabled/hubble_ui_enabled can do anything."
  type        = bool
  default     = true
}

variable "hubble_relay_enabled" {
  description = "Enable the Hubble Relay deployment. Defaults to false: relay/UI are part of the same Helm chart/release as Cilium itself (see AGENTS.md for why this can't be a second, independent Helm release), so the hubble module flips this on rather than installing anything of its own."
  type        = bool
  default     = false
}

variable "hubble_ui_enabled" {
  description = "Enable the Hubble UI deployment. Same caveat as hubble_relay_enabled."
  type        = bool
  default     = false
}


# ─────────────────────────────────────────────
# Helm release behavior
# ─────────────────────────────────────────────

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
