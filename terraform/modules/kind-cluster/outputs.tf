output "name" {
  description = "Name of the Kind cluster."
  value       = kind_cluster.this.name
}

output "kubeconfig_path" {
  description = "Absolute path to the written kubeconfig file."
  value       = kind_cluster.this.kubeconfig_path
}

output "kubeconfig" {
  description = "Full kubeconfig content as a string. Use this to configure the kubernetes/helm providers without relying on a file on disk."
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}

output "endpoint" {
  description = "URL of the Kubernetes API server."
  value       = kind_cluster.this.endpoint
}

output "client_certificate" {
  description = "Client certificate for authenticating to the cluster."
  value       = kind_cluster.this.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for authenticating to the cluster."
  value       = kind_cluster.this.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate for verifying the API server's TLS certificate."
  value       = kind_cluster.this.cluster_ca_certificate
  sensitive   = true
}
