output "namespace" {
  description = "Namespace of Argo CD, from the Namespace manifest in manifests_dir."
  value       = one([for doc in values(local.foundation) : yamldecode(doc).metadata.name if yamldecode(doc).kind == "Namespace"])
}

output "manifest_keys" {
  description = "Keys (<kind>/<namespace>/<name>) of the resources that the bootstrap applied."
  value       = keys(local.manifests)
}
