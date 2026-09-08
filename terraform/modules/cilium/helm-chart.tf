resource "helm_release" "cilium" {
  name      = var.release_name
  namespace = var.namespace

  # Digest pinning takes precedence when set: the full OCI reference
  # (repository@sha256:digest) already identifies exact chart content, so
  # repository/version are left unset in that case.
  repository = var.chart_digest == "" ? "oci://quay.io/cilium/charts" : null
  chart      = var.chart_digest == "" ? "cilium" : "oci://quay.io/cilium/charts/cilium@${var.chart_digest}"
  version    = var.chart_digest == "" ? var.chart_version : null

  wait    = var.wait
  timeout = var.timeout

  values = [
    templatefile("${path.module}/templates/cilium-values.yaml.tftpl", local.cilium_values)
  ]

  depends_on = [kubernetes_namespace_v1.this]
}
