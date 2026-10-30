locals {
  # Full image reference with digest pinning for reproducibility
  node_image = format(
    "%s:%s@sha256:%s",
    var.node_image,
    var.node_image_tag,
    var.node_image_digest,
  )

  # Default kubeconfig path isolates the cluster from ~/.kube/config to avoid conflicts
  kubeconfig_path = var.kubeconfig_path != "" ? pathexpand(var.kubeconfig_path) : pathexpand("~/.kube/kind-${var.name}")

  # Node lists used by dynamic blocks in main.tf
  control_plane_nodes = [for i in range(var.control_plane_count) : { role = "control-plane" }]
  worker_nodes        = [for i in range(var.worker_count) : { role = "worker" }]

  # Extra CA files, mounted into /etc/ssl/certs of each node. containerd (Go) reads
  # every file in that folder, so the node trusts the CA with no update-ca-certificates.
  # The file name comes from a hash of the path, so a new order of the list does not
  # replace the cluster.
  extra_ca_mounts = [
    for p in var.extra_ca_certificate_paths : {
      host_path      = abspath(pathexpand(p))
      container_path = "/etc/ssl/certs/extra-ca-${substr(sha256(abspath(pathexpand(p))), 0, 12)}.pem"
    }
  ]
}
