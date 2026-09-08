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

resource "terraform_data" "kind_bpf_sysctls" {
  count = var.enable_bpf_sysctls ? 1 : 0

  triggers_replace = [
    kind_cluster.this.id
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      for node in $(docker ps --filter "label=io.x-k8s.kind.cluster=${var.name}" --format '{{.Names}}'); do
        echo "Installing BPF sysctl service on Kind node: $node"
        docker exec "$node" bash -c '
          cat <<EOF > /etc/systemd/system/kind-bpf-sysctl.service
[Unit]
Description=Inject root-netns sysctls for Cilium BPF Bandwidth Manager
Before=kubelet.service cilium.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "if [ ! -f /proc/sys/net/core/default_qdisc ]; then mkdir -p /tmp/fake-core && cp -a /proc/sys/net/core/* /tmp/fake-core/ && echo fq > /tmp/fake-core/default_qdisc && echo 1000 > /tmp/fake-core/netdev_max_backlog && mount --bind /tmp/fake-core /proc/sys/net/core; fi"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
          systemctl daemon-reload
          systemctl enable --now kind-bpf-sysctl.service
        '
      done
    EOT
  }
}
