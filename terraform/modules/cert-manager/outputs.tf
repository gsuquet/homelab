output "namespace" {
  description = "Namespace cert-manager was installed into."
  value       = var.namespace
}

output "release_name" {
  description = "Name of the Helm release."
  value       = helm_release.cert_manager.name
}

output "release_status" {
  description = "Status of the Helm release, as reported by Helm."
  value       = helm_release.cert_manager.status
}

output "crds_enabled" {
  description = "Whether cert-manager CRDs are managed by this module."
  value       = var.crds_enabled
}

output "enable_gateway_api" {
  description = "Whether Gateway API support is enabled in cert-manager."
  value       = var.enable_gateway_api
}

output "selfsigned_issuer_name" {
  description = "Name of the self-signed ClusterIssuer if enabled."
  value       = var.enable_selfsigned_issuer ? "selfsigned" : null
}

output "letsencrypt_staging_issuer_name" {
  description = "Name of the Let's Encrypt Staging ClusterIssuer if enabled."
  value       = var.enable_letsencrypt_staging_issuer ? "letsencrypt-staging" : null
}

output "letsencrypt_prod_issuer_name" {
  description = "Name of the Let's Encrypt Production ClusterIssuer if enabled."
  value       = var.enable_letsencrypt_prod_issuer ? "letsencrypt-prod" : null
}
