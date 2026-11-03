module "kind_cluster" {
  source = "../../modules/cluster-kind"

  name                = "kind-local"
  disable_default_cni = true
  worker_count        = 1

  extra_ca_certificate_paths = var.extra_ca_certificate_paths

  # /proc of the Docker host (the Colima VM), for Tetragon, which must see the
  # VM root PID namespace. read_only stops writes to procfs files only. It is not
  # an isolation boundary: /procHost/<pid>/root reaches the whole VM. Not verified
  # that Tetragon works with a read-only mount (checked in step 6). A change
  # replaces the cluster.
  extra_mounts = [
    {
      host_path      = "/proc"
      container_path = "/procHost"
      read_only      = true
    }
  ]
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

# Argo CD starts from the same rendered manifests that it syncs from Git. Then
# it manages itself and the components in gitops/clusters/kind-local/cluster.yaml.
module "argocd" {
  source = "../../modules/bootstrap-argocd"

  manifests_dir = "${path.module}/../../gitops/clusters/kind-local/rendered/argocd"

  depends_on = [module.cilium]
}
