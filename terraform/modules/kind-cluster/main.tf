resource "kind_cluster" "this" {
  name            = var.name
  node_image      = local.node_image
  kubeconfig_path = local.kubeconfig_path
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      pod_subnet          = var.pod_subnet != "" ? var.pod_subnet : null
      service_subnet      = var.service_subnet != "" ? var.service_subnet : null
      disable_default_cni = var.disable_default_cni
      api_server_address  = var.api_server_address != "" ? var.api_server_address : null
      api_server_port     = var.api_server_port != 0 ? var.api_server_port : null
    }

    # Control-plane nodes — port mappings and kubeadm patches applied here
    dynamic "node" {
      for_each = local.control_plane_nodes
      content {
        role                   = node.value.role
        kubeadm_config_patches = var.control_plane_kubeadm_config_patches

        dynamic "extra_port_mappings" {
          for_each = var.extra_port_mappings
          content {
            container_port = extra_port_mappings.value.container_port
            host_port      = extra_port_mappings.value.host_port
            protocol       = extra_port_mappings.value.protocol
          }
        }
      }
    }

    # Worker nodes
    dynamic "node" {
      for_each = local.worker_nodes
      content {
        role                   = node.value.role
        kubeadm_config_patches = var.worker_kubeadm_config_patches
      }
    }
  }
}
