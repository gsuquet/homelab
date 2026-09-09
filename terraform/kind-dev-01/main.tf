module "kind_cluster" {
  source = "../modules/kind-cluster"

  name                = "kind-dev-01"
  disable_default_cni = true
  worker_count        = 1
}

module "cilium" {
  source = "../modules/cilium"

  cluster_name         = module.kind_cluster.name
  cluster_type         = "kind"
  k8s_service_host     = "${module.kind_cluster.name}-control-plane"
  k8s_service_port     = "6443"
  hubble_relay_enabled = true
  hubble_ui_enabled    = true

  depends_on = [module.kind_cluster]
}
