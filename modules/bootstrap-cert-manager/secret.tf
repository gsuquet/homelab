resource "kubernetes_secret_v1" "cloudflare_api_token" {
  count = var.enable_cloudflare_dns01_solver && var.create_cloudflare_secret && var.cloudflare_api_token != "" ? 1 : 0

  metadata {
    name      = var.cloudflare_api_token_secret_name
    namespace = var.namespace
  }

  data = {
    api-token = var.cloudflare_api_token
  }

  depends_on = [kubernetes_namespace_v1.this]
}
