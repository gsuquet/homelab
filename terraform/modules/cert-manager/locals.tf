locals {
  controller_extra_args = concat(
    var.enable_gateway_api ? ["--enable-gateway-api"] : [],
    var.controller_extra_args
  )

  # Custom solvers formatted as indented YAML string if provided
  custom_solvers_yaml = length(var.acme_custom_solvers) > 0 ? indent(6, yamlencode(var.acme_custom_solvers)) : ""

  # Template values for the ACME ClusterIssuer manifests
  acme_issuer_values = {
    COMMON_LABELS                  = var.common_labels
    ACME_EMAIL                     = var.acme_email
    ENABLE_GATEWAY_API_SOLVER      = var.enable_gateway_api_solver
    GATEWAY_NAME                   = var.gateway_name
    GATEWAY_NAMESPACE              = var.gateway_namespace
    GATEWAY_KIND                   = var.gateway_kind
    GATEWAY_GROUP                  = var.gateway_group
    ENABLE_CLOUDFLARE_DNS01_SOLVER = var.enable_cloudflare_dns01_solver
    CLOUDFLARE_SECRET_NAME         = var.cloudflare_api_token_secret_name
    CLOUDFLARE_DNS01_ZONES         = var.cloudflare_dns01_zones
    CLOUDFLARE_DNS01_DOMAINS       = var.cloudflare_dns01_domains
    CUSTOM_SOLVERS_YAML            = local.custom_solvers_yaml
  }

  # Template values for the self-signed ClusterIssuer manifest
  selfsigned_issuer_values = {
    COMMON_LABELS = var.common_labels
  }

  # Template values for the cert-manager Helm chart values template
  cert_manager_values = {
    COMMON_LABELS                     = jsonencode(var.common_labels)
    LOG_LEVEL                         = var.log_level
    LEADER_ELECTION_NAMESPACE         = var.leader_election_namespace != "" ? var.leader_election_namespace : "kube-system"
    CRDS_ENABLED                      = var.crds_enabled
    CRDS_KEEP                         = var.crds_keep
    CONTROLLER_REPLICAS               = var.controller_replicas
    CONTROLLER_EXTRA_ARGS             = jsonencode(local.controller_extra_args)
    PROMETHEUS_SERVICEMONITOR_ENABLED = var.prometheus_servicemonitor_enabled
    WEBHOOK_REPLICAS                  = var.webhook_replicas
    CAINJECTOR_REPLICAS               = var.cainjector_replicas
  }
}
