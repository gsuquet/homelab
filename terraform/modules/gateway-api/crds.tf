data "kubectl_file_documents" "standard" {
  content = file("${path.module}/manifests/standard-install.yaml")
}

data "kubectl_file_documents" "experimental" {
  content = file("${path.module}/manifests/experimental-install.yaml")
}

resource "kubectl_manifest" "standard" {
  for_each = var.channel == "standard" ? data.kubectl_file_documents.standard.manifests : {}

  yaml_body         = each.value
  server_side_apply = var.server_side_apply
  force_conflicts   = var.force_conflicts
  wait              = var.wait
}

resource "kubectl_manifest" "experimental" {
  for_each = var.channel == "experimental" ? data.kubectl_file_documents.experimental.manifests : {}

  yaml_body         = each.value
  server_side_apply = var.server_side_apply
  force_conflicts   = var.force_conflicts
  wait              = var.wait
}
