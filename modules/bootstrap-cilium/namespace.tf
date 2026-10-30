resource "kubernetes_namespace_v1" "this" {
  count = local.create_namespace ? 1 : 0

  metadata {
    name = var.namespace
  }
}
