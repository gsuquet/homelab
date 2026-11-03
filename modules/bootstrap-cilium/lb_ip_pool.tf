# Cilium LB IPAM gives an address to each Service of type LoadBalancer from a
# pool. The pool is optional: without `lb_ip_pool`, no pool exists. L2
# announcements stay off (l2announcements.enabled is false in the values file),
# so the addresses only make the Services and Gateways ready. No traffic uses them.
resource "kubectl_manifest" "lb_ip_pool" {
  count = var.lb_ip_pool == null ? 0 : 1

  yaml_body = yamlencode({
    apiVersion = "cilium.io/v2"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name   = var.lb_ip_pool.name
      labels = var.common_labels
    }
    spec = {
      blocks = [{
        start = var.lb_ip_pool.start
        stop  = var.lb_ip_pool.stop
      }]
    }
  })

  # The operator registers the CRD after it starts. The Helm release waits for it.
  depends_on = [helm_release.cilium]
}
