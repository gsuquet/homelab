output "channel" {
  description = "The installed Gateway API release channel ('standard' or 'experimental')."
  value       = var.channel
}

output "version" {
  description = "The version of Gateway API CRD manifests bundled with this module."
  value       = "v1.6.2"
}

output "crd_names" {
  description = "List of CRD resource identifiers deployed by this module."
  value       = keys(local.manifests)
}

output "crd_count" {
  description = "Total number of CRD documents applied."
  value       = length(local.manifests)
}
