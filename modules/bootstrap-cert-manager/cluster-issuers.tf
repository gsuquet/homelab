resource "kubectl_manifest" "selfsigned" {
  count = var.enable_selfsigned_issuer ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/cluster-issuer-selfsigned.yaml.tftpl", local.selfsigned_issuer_values)

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "letsencrypt_staging" {
  count = var.enable_letsencrypt_staging_issuer ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/cluster-issuer-letsencrypt-staging.yaml.tftpl", local.acme_issuer_values)

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "letsencrypt_prod" {
  count = var.enable_letsencrypt_prod_issuer ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/cluster-issuer-letsencrypt-prod.yaml.tftpl", local.acme_issuer_values)

  depends_on = [helm_release.cert_manager]
}
