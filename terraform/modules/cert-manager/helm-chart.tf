resource "helm_release" "cert_manager" {
  name      = var.release_name
  namespace = var.namespace

  # Digest pinning takes precedence when set: the full OCI reference
  # (repository@sha256:digest) already identifies exact chart content, so
  # repository/version are left unset in that case.
  repository = var.chart_digest == "" ? "oci://quay.io/jetstack/charts" : null
  chart      = var.chart_digest == "" ? "cert-manager" : "oci://quay.io/jetstack/charts/cert-manager@${var.chart_digest}"
  version    = var.chart_digest == "" ? var.chart_version : null

  wait    = var.wait
  timeout = var.timeout

  values = [
    templatefile("${path.module}/templates/cert-manager-values.yaml.tftpl", local.cert_manager_values)
  ]

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.cloudflare_api_token,
  ]
}
