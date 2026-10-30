module "kind_cluster" {
  source = "../../modules/cluster-kind"

  name                = "kind-local"
  disable_default_cni = true
  worker_count        = 1

  extra_ca_certificate_paths = var.extra_ca_certificate_paths
}

module "gateway_api" {
  source = "../../modules/bootstrap-gateway-api"

  channel = "standard"

  depends_on = [module.kind_cluster]
}

module "cilium" {
  source = "../../modules/bootstrap-cilium"

  cluster_name         = module.kind_cluster.name
  cluster_type         = "kind"
  k8s_service_host     = "${module.kind_cluster.name}-control-plane"
  k8s_service_port     = "6443"
  hubble_relay_enabled = true
  hubble_ui_enabled    = true

  depends_on = [module.kind_cluster, module.gateway_api]
}

module "agent_sandbox" {
  source = "../../modules/bootstrap-agent-sandbox"

  enable_extensions = true

  depends_on = [module.cilium]
}
