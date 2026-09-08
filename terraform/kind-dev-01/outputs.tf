output "kubeconfig_path" {
  description = "Absolute path to the written kubeconfig file."
  value       = module.kind_cluster.kubeconfig_path
}

output "cilium_release_status" {
  description = "Status of the Cilium Helm release."
  value       = module.cilium.release_status
}
