# Cilium LB IPAM gives an address to each Service of type LoadBalancer from a
# pool. The pool is optional: without `lb_ip_pool`, no pool exists. L2
# announcements stay off (l2announcements.enabled is false in the values file),
# so the addresses only make the Services and Gateways ready. No traffic uses them.
# The operator registers the CRD after it starts, and a ready Helm release does
# not prove that it did. Wait for the CRD, else the first apply can fail on a
# missing kind. Needs the kubectl CLI.
resource "terraform_data" "wait_lb_ip_pool_crd" {
  count = var.lb_ip_pool == null || var.kubeconfig_path == "" ? 0 : 1

  provisioner "local-exec" {
    command = "kubectl --kubeconfig '${var.kubeconfig_path}' wait --for=condition=Established crd/ciliumloadbalancerippools.cilium.io --timeout=${var.lb_ip_pool_crd_timeout}s"
  }

  depends_on = [helm_release.cilium]
}

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

  depends_on = [helm_release.cilium, terraform_data.wait_lb_ip_pool_crd]
}
