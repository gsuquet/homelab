# ─────────────────────────────────────────────
# Cluster identity
# ─────────────────────────────────────────────

variable "name" {
  description = "Name of the Kind cluster. Must be lowercase alphanumeric and hyphens only."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path where the kubeconfig will be written. Defaults to ~/.kube/kind-<name> to avoid polluting the default kubeconfig."
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────
# Node image (pinned for reproducibility)
# ─────────────────────────────────────────────

variable "node_image" {
  description = "Base image name for Kind nodes (without tag or digest)."
  type        = string
  default     = "kindest/node"
}

variable "node_image_tag" {
  description = "Kubernetes version tag for the node image (e.g. v1.36.1)."
  type        = string
  default     = "v1.36.1"
}

variable "node_image_digest" {
  description = "SHA256 digest of the node image for reproducible, tamper-resistant builds. Find the digest for a given release at https://github.com/kubernetes-sigs/kind/releases."
  type        = string
  default     = "3489c7674813ba5d8b1a9977baea8a6e553784dab7b84759d1014dbd78f7ebd5"
}

# ─────────────────────────────────────────────
# Node topology
# ─────────────────────────────────────────────

variable "control_plane_count" {
  description = "Number of control-plane nodes. Must be 1 for a standard cluster (HA control-plane is experimental in Kind)."
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2
}

# ─────────────────────────────────────────────
# Port mappings (applied to all control-plane nodes)
# ─────────────────────────────────────────────

variable "extra_port_mappings" {
  description = "Extra port mappings to expose from the control-plane node to the host. Commonly used to expose an ingress controller (e.g., host_port=80 → container_port=80)."
  type = list(object({
    container_port = number
    host_port      = number
    protocol       = optional(string, "TCP")
  }))
  default = []
}

# ─────────────────────────────────────────────
# Kubeadm config patches (per node role)
# ─────────────────────────────────────────────

variable "control_plane_kubeadm_config_patches" {
  description = "List of kubeadm InitConfiguration/ClusterConfiguration YAML patches applied to each control-plane node. Useful for adding node labels, taints, or kubelet arguments."
  type        = list(string)
  default     = []
}

variable "worker_kubeadm_config_patches" {
  description = "List of kubeadm JoinConfiguration YAML patches applied to each worker node. Useful for adding node labels or kubelet arguments."
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────
# Networking
# ─────────────────────────────────────────────

variable "pod_subnet" {
  description = "CIDR range for pod IPs. Leave empty to use the Kind default (10.244.0.0/16). Set to match your production cluster for staging environments."
  type        = string
  default     = ""
}

variable "service_subnet" {
  description = "CIDR range for service IPs. Leave empty to use the Kind default (10.96.0.0/12). Set to match your production cluster for staging environments."
  type        = string
  default     = ""
}

variable "disable_default_cni" {
  description = "Disable the default CNI plugin (kindnet). Set to true when installing a custom CNI such as Cilium or Calico."
  type        = bool
  default     = false
}

variable "api_server_address" {
  description = "Address on which the API server will listen. Leave empty to use the Kind default (127.0.0.1)."
  type        = string
  default     = ""
}

variable "api_server_port" {
  description = "Port on which the API server will listen. Set to 0 to use a random available port (Kind default)."
  type        = number
  default     = 0
}
