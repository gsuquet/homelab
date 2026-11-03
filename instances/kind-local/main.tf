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

# Docker picks the subnet of the `kind` network for each host, so the pool
# cannot be a constant. The network exists after the cluster module. The docker
# CLI is the same tool that the cluster-kind module uses.
data "external" "kind_network" {
  program = [
    "sh", "-c",
    "set -e; printf '{\"subnets\":\"%s\"}' \"$(docker network inspect kind --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}')\""
  ]

  depends_on = [module.kind_cluster]
}

locals {
  # The network has an IPv4 and an IPv6 subnet. Take the IPv4 one.
  kind_ipv4_subnet = one([for s in split(" ", trimspace(data.external.kind_network.result.subnets)) : s if length(regexall(":", s)) == 0])

  # The last 100 addresses before the broadcast address. Docker gives container
  # addresses from the start of the subnet, so the pool does not meet the nodes.
  lb_pool_start = cidrhost(local.kind_ipv4_subnet, -101)
  lb_pool_stop  = cidrhost(local.kind_ipv4_subnet, -2)
}

module "cilium" {
  source = "../../modules/bootstrap-cilium"

  cluster_name         = module.kind_cluster.name
  cluster_type         = "kind"
  k8s_service_host     = "${module.kind_cluster.name}-control-plane"
  k8s_service_port     = "6443"
  hubble_relay_enabled = true
  hubble_ui_enabled    = true

  # One pool, L2 announcements off: Gateways get an address and become
  # Programmed, but no traffic uses the address. The host uses kubectl port-forward.
  lb_ip_pool = {
    name  = "kind-local"
    start = local.lb_pool_start
    stop  = local.lb_pool_stop
  }

  depends_on = [module.kind_cluster, module.gateway_api]
}

# Argo CD starts from the same rendered manifests that it syncs from Git. Then
# it manages itself and the components in gitops/clusters/kind-local/cluster.yaml.
module "argocd" {
  source = "../../modules/bootstrap-argocd"

  manifests_dir = "${path.module}/../../gitops/clusters/kind-local/rendered/argocd"

  depends_on = [module.cilium]
}
