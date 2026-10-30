# Terraform installs Argo CD once from the rendered manifests. Then Argo CD
# syncs the same folder from Git and manages itself: the upgrades come from Git.
# Thus each resource ignores all changes after its creation.
#
# The documents are split in locals, as in bootstrap-gateway-api: Terraform
# knows the keys at plan time, also before the cluster exists.
locals {
  documents = flatten([
    for file_name in sort(fileset(var.manifests_dir, "*.yaml")) : [
      for doc in split("\n---\n", file("${var.manifests_dir}/${file_name}")) : doc
      if try(yamldecode(doc).kind, null) != null
    ]
  ])

  manifests = {
    for doc in local.documents :
    join("/", compact([yamldecode(doc).kind, try(yamldecode(doc).metadata.namespace, ""), yamldecode(doc).metadata.name])) => doc
  }

  # 1. The namespace and the CRDs. 2. The Argo CD components. 3. The Argo CD
  # resources (AppProject, ApplicationSet), when the CRDs and the controllers exist.
  foundation_kinds = ["Namespace", "CustomResourceDefinition"]

  foundation = { for key, doc in local.manifests : key => doc if contains(local.foundation_kinds, yamldecode(doc).kind) }
  argocd_resources = {
    for key, doc in local.manifests : key => doc
    if startswith(yamldecode(doc).apiVersion, "argoproj.io/")
  }
  components = {
    for key, doc in local.manifests : key => doc
    if !contains(keys(local.foundation), key) && !contains(keys(local.argocd_resources), key)
  }
}

resource "kubectl_manifest" "foundation" {
  for_each = local.foundation

  yaml_body         = each.value
  server_side_apply = true
  force_conflicts   = var.force_conflicts

  lifecycle {
    ignore_changes = all
  }
}

resource "kubectl_manifest" "components" {
  for_each = local.components

  yaml_body         = each.value
  server_side_apply = true
  force_conflicts   = var.force_conflicts
  wait_for_rollout  = var.wait_for_rollout

  lifecycle {
    ignore_changes = all
  }

  depends_on = [kubectl_manifest.foundation]
}

resource "kubectl_manifest" "argocd_resources" {
  for_each = local.argocd_resources

  yaml_body         = each.value
  server_side_apply = true
  force_conflicts   = var.force_conflicts

  lifecycle {
    ignore_changes = all
  }

  depends_on = [kubectl_manifest.components]
}
