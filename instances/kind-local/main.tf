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
# CLI is the same tool that the cluster-kind module uses, so this works with
# Docker and Colima. Podman (KIND_EXPERIMENTAL_PROVIDER) is not supported.
# The program fails with a message on stderr if docker fails or prints nothing.
data "external" "kind_network" {
  program = [
    "sh", "-c",
    <<-EOT
      s=$(docker network inspect kind --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}') || exit 1
      [ -n "$s" ] || { echo "no subnet on the Docker network kind" >&2; exit 1; }
      printf '{"subnets":"%s"}' "$s"
    EOT
  ]

  depends_on = [module.kind_cluster]
}

locals {
  # The network has an IPv4 and an IPv6 subnet. Take the IPv4 ones.
  kind_ipv4_subnets = [
    for s in split(" ", trimspace(data.external.kind_network.result.subnets)) : s
    if s != "" && length(regexall(":", s)) == 0
  ]
  kind_ipv4_subnet = length(local.kind_ipv4_subnets) == 1 ? local.kind_ipv4_subnets[0] : ""

  # The last 100 addresses before the broadcast address. Docker gives container
  # addresses from the start of the subnet, so the pool does not meet the nodes.
  # The check below needs a prefix of /24 or shorter (at least 254 hosts).
  lb_pool_start = local.kind_ipv4_subnet == "" ? "" : cidrhost(local.kind_ipv4_subnet, -101)
  lb_pool_stop  = local.kind_ipv4_subnet == "" ? "" : cidrhost(local.kind_ipv4_subnet, -2)
}

check "kind_network_subnet" {
  assert {
    condition     = length(local.kind_ipv4_subnets) == 1 && tonumber(split("/", local.kind_ipv4_subnet)[1]) <= 24
    error_message = "The Docker network kind must have exactly one IPv4 subnet with a prefix of /24 or shorter, for the Cilium LB pool. Found: ${join(", ", local.kind_ipv4_subnets)}."
  }
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
  # The wait needs the kubectl CLI on the host and the kubeconfig of the cluster.
  kubeconfig_path = module.kind_cluster.kubeconfig_path
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
