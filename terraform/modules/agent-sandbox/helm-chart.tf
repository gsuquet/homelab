resource "helm_release" "agent_sandbox" {
  name      = var.release_name
  namespace = var.namespace

  chart = "${path.module}/charts/agent-sandbox"

  wait    = var.wait
  timeout = var.timeout

  values = [
    templatefile("${path.module}/templates/agent-sandbox-values.yaml.tftpl", local.agent_sandbox_values)
  ]

  depends_on = [kubernetes_namespace_v1.this]
}
