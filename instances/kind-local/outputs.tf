output "kubeconfig_path" {
  description = "Absolute path to the written kubeconfig file."
  value       = module.kind_cluster.kubeconfig_path
}

output "cilium_release_status" {
  description = "Status of the Cilium Helm release."
  value       = module.cilium.release_status
}

output "gateway_api_channel" {
  description = "Channel installed for Gateway API."
  value       = module.gateway_api.channel
}

output "agent_sandbox_release_status" {
  description = "Status of the agent-sandbox Helm release."
  value       = module.agent_sandbox.release_status
}
