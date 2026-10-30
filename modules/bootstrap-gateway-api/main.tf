# Split the bundled install file into one manifest for each resource. The keys
# come from the file content, so Terraform knows them at plan time, also before
# the cluster exists. A comment-only document has no kind and is skipped.
locals {
  manifest_file = "${path.module}/manifests/${var.channel}-install.yaml"

  manifests = {
    for doc in split("\n---\n", file(local.manifest_file)) :
    "${yamldecode(doc).kind}/${yamldecode(doc).metadata.name}" => doc
    if try(yamldecode(doc).kind, null) != null
  }
}

resource "kubectl_manifest" "this" {
  for_each = local.manifests

  yaml_body         = each.value
  server_side_apply = var.server_side_apply
  force_conflicts   = var.force_conflicts
  wait              = var.wait
}
