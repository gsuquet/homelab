variable "rewrite_hostnames" {
  description = "Host names that CoreDNS rewrites to rewrite_target. Pods that resolve one of these names get the address of the target Service. An empty list adds no rule."
  type        = list(string)

  validation {
    condition     = alltrue([for h in var.rewrite_hostnames : can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", h))])
    error_message = "Each host name must use lowercase letters, digits, dots and hyphens."
  }
}

variable "rewrite_target" {
  description = "Fully qualified name of the Service that receives the rewritten names, for example gateway.example.svc.cluster.local."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.rewrite_target))
    error_message = "The target must be a lowercase DNS name."
  }
}

variable "namespace" {
  description = "Namespace of the coredns ConfigMap. kubeadm makes it in kube-system."
  type        = string
  default     = "kube-system"
}

variable "config_map_name" {
  description = "Name of the CoreDNS ConfigMap that kubeadm makes."
  type        = string
  default     = "coredns"
}

variable "field_manager" {
  description = "Field manager name that Terraform uses for the Corefile key."
  type        = string
  default     = "terraform-bootstrap-coredns"
}
