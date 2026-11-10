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
  description = "Kubernetes version tag for the node image (e.g. v1.37.0)."
  type        = string
  default     = "v1.37.0"
}

variable "node_image_digest" {
  description = "SHA256 digest of the node image for reproducible, tamper-resistant builds. The reference is the default node image compiled into the pinned kind binary. Release notes: https://github.com/kubernetes-sigs/kind/releases."
  type        = string
  default     = "a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
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

variable "kube_proxy_mode" {
  description = "Kube-proxy mode ('iptables', 'ipvs', or 'none'). Set to 'none' when using Cilium in kube-proxy replacement mode."
  type        = string
  default     = "none"
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

# ─────────────────────────────────────────────
# Workarounds & Compatibility
# ─────────────────────────────────────────────

variable "enable_bpf_sysctls" {
  description = "Workaround for Cilium Bandwidth Manager and BBR in Kind clusters. Installs a systemd service inside each Kind node to bind-mount fake /proc/sys/net/core with default_qdisc and netdev_max_backlog."
  type        = bool
  default     = true
}

variable "extra_ca_certificate_paths" {
  description = "PEM files of extra CAs that the nodes must trust, for example the CA of a TLS-inspecting proxy. Each file is mounted read-only into every node. The Docker daemon reads the path, so the file must be in a folder that the Docker VM mounts (for Colima: your home folder). A change replaces the cluster."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for p in var.extra_ca_certificate_paths : fileexists(pathexpand(p))])
    error_message = "Each path in extra_ca_certificate_paths must be an existing file."
  }
}

variable "extra_mounts" {
  description = "Extra host paths to mount into every node, for example the /proc of the Docker VM. read_only (default true) only stops writes to the mounted files. It is not an isolation boundary: for /proc, /proc/<pid>/root still reaches the whole Docker host. The Docker daemon reads host_path, so the path is on the Docker VM, not always on your machine. The module does not check that host_path exists. A change replaces the cluster."
  type = list(object({
    host_path      = string
    container_path = string
    read_only      = optional(bool, true)
  }))
  default = []

  validation {
    condition     = alltrue([for m in var.extra_mounts : startswith(m.host_path, "/") && startswith(m.container_path, "/")])
    error_message = "Each host_path and container_path in extra_mounts must be an absolute path."
  }

  validation {
    condition = alltrue([
      for m in var.extra_mounts :
      !contains(["", "/proc", "/sys", "/dev", "/etc", "/usr", "/bin", "/lib", "/var", "/var/lib", "/var/lib/containerd", "/var/lib/kubelet"], trimsuffix(m.container_path, "/"))
    ])
    error_message = "A container_path in extra_mounts must not be / or a path that the node needs, for example /proc, /sys, /dev, /etc or /var/lib/containerd."
  }

  validation {
    condition     = length(distinct([for m in var.extra_mounts : trimsuffix(m.container_path, "/")])) == length(var.extra_mounts)
    error_message = "Each container_path in extra_mounts must be unique."
  }

  validation {
    condition     = alltrue([for m in var.extra_mounts : !startswith(m.container_path, "/etc/ssl/certs/extra-ca-")])
    error_message = "A container_path in extra_mounts must not start with /etc/ssl/certs/extra-ca-. The module uses that prefix for extra_ca_certificate_paths."
  }
}
