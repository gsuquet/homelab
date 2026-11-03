locals {
  rewrite_rules = [
    for h in var.rewrite_hostnames : "    rewrite name exact ${h} ${var.rewrite_target}"
  ]

  rewrite_block = length(local.rewrite_rules) == 0 ? "" : "${join("\n", local.rewrite_rules)}\n"

  # The Corefile is the kubeadm default of Kubernetes 1.37 (kind v1.37.0), plus
  # the rewrite rules. A rewrite must come before the kubernetes plugin. The
  # reload plugin applies a change to the ConfigMap, so no pod restart is needed.
  corefile = <<-EOT
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
    ${local.rewrite_block}    kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30 {
           disable success cluster.local
           disable denial cluster.local
        }
        loop
        reload
        loadbalance
    }
  EOT
}

# kubeadm owns the ConfigMap. This resource takes over only the Corefile key
# (force = true, own field manager), so it does not need to import the ConfigMap.
resource "kubernetes_config_map_v1_data" "corefile" {
  force         = true
  field_manager = var.field_manager

  metadata {
    name      = var.config_map_name
    namespace = var.namespace
  }

  data = {
    Corefile = local.corefile
  }
}
