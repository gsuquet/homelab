output "namespace" {
  description = "Namespace Cilium was installed into."
  value       = var.namespace
}

output "release_name" {
  description = "Name of the Helm release."
  value       = helm_release.cilium.name
}

output "release_status" {
  description = "Status of the Helm release, as reported by Helm."
  value       = helm_release.cilium.status
}

output "hubble_relay_enabled" {
  description = "Whether Hubble Relay is enabled on this release. Consumed by the hubble module to know whether it still needs to flip this on."
  value       = var.hubble_relay_enabled
}

output "hubble_ui_enabled" {
  description = "Whether the Hubble UI is enabled on this release. Consumed by the hubble module to know whether it still needs to flip this on."
  value       = var.hubble_ui_enabled
}

output "host_firewall_enabled" {
  description = "Whether Cilium Host Firewall is enabled on this release."
  value       = var.host_firewall_enabled
}

output "egress_gateway_enabled" {
  description = "Whether Cilium Egress Gateway is enabled on this release."
  value       = var.egress_gateway_enabled
}
