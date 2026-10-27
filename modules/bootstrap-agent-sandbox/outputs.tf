output "namespace" {
  description = "Namespace the agent-sandbox controller was installed into."
  value       = var.namespace
}

output "release_name" {
  description = "Name of the Helm release."
  value       = helm_release.agent_sandbox.name
}

output "release_status" {
  description = "Status of the Helm release, as reported by Helm."
  value       = helm_release.agent_sandbox.status
}

output "version" {
  description = "Image version tag of the agent-sandbox controller deployed."
  value       = var.image_tag
}

output "extensions_enabled" {
  description = "Whether agent-sandbox extensions (SandboxTemplate, SandboxWarmPool, SandboxClaim) are enabled."
  value       = var.enable_extensions
}
