resource "kind_cluster" "this" {
  name = var.name
  node_image = format("%s:%s@sha256:%s",var.node_image, var.node_image_tag, var.node_image_digest)
  kubeconfig_path = pathexpand(var.kubeconfig_path)
  wait_for_ready = true

  kind_config = {
    api_version = ""
    kind = "Cluster"
  }
}
