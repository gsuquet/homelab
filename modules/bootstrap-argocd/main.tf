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

  # A Helm hook Job (redis-secret-init) deletes itself after it runs, and Argo
  # CD runs it again as a PreSync hook. Terraform applies a renamed copy without
  # the hook annotations and without the TTL, so the plan stays clean. Argo CD
  # does not track the copy.
  bodies = [
    for doc in local.documents : (
      yamldecode(doc).kind == "Job" && can(yamldecode(doc).metadata.annotations["helm.sh/hook"])
      ? yamlencode(merge(yamldecode(doc), {
        metadata = merge(
          { for key, value in yamldecode(doc).metadata : key => value if key != "annotations" },
          { name = "${yamldecode(doc).metadata.name}-bootstrap" },
        )
        spec = { for key, value in yamldecode(doc).spec : key => value if key != "ttlSecondsAfterFinished" }
      }))
      : doc
    )
  ]

  manifests = {
    for body in local.bodies :
    join("/", compact([yamldecode(body).kind, try(yamldecode(body).metadata.namespace, ""), yamldecode(body).metadata.name])) => body
  }

  # 1. The namespace and the CRDs. 2. The Argo CD components. 3. The Argo CD
  # resources (AppProject, ApplicationSet), when the CRDs and the controllers exist.
  foundation_kinds = ["Namespace", "CustomResourceDefinition"]

  # The field manager of the Argo CD application controller. Terraform applies
  # as this manager, so the first sync of Argo CD owns all the fields. If
  # Terraform used its own manager, a field that a later commit removes would
  # stay in the cluster, because the Terraform manager would still own it.
  field_manager = "argocd-controller"

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
  field_manager     = local.field_manager
  force_conflicts   = var.force_conflicts

  lifecycle {
    ignore_changes = all
  }
}

resource "kubectl_manifest" "components" {
  for_each = local.components

  yaml_body         = each.value
  server_side_apply = true
  field_manager     = local.field_manager
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
  field_manager     = local.field_manager
  force_conflicts   = var.force_conflicts

  lifecycle {
    ignore_changes = all
  }

  depends_on = [kubectl_manifest.components]
}
