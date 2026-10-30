variable "manifests_dir" {
  description = "Folder with the rendered Argo CD manifests of the instance: gitops/platform/argocd/rendered/<instance>. Argo CD syncs the same folder after the bootstrap."
  type        = string

  validation {
    condition     = length(fileset(var.manifests_dir, "*.yaml")) > 0
    error_message = "The folder has no YAML files. Run 'mise run manifests:render' and set the folder of the instance."
  }
}

variable "force_conflicts" {
  description = "Take the ownership of fields that another field manager owns. Argo CD takes the fields back on its first sync."
  type        = bool
  default     = true
}

variable "wait_for_rollout" {
  description = "Wait until the Argo CD Deployments and StatefulSets are ready before the apply completes."
  type        = bool
  default     = true
}
