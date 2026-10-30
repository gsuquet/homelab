locals {
  agent_sandbox_values = {
    NAMESPACE                         = var.namespace
    IMAGE_TAG                         = var.image_tag
    REPLICA_COUNT                     = var.replica_count
    EXTENSIONS_ENABLED                = var.enable_extensions
    PROMETHEUS_SERVICEMONITOR_ENABLED = var.prometheus_servicemonitor_enabled
  }
}
