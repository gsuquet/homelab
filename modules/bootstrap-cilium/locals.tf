locals {
  # kube-system always exists; anything else must be created by this module.
  create_namespace = var.namespace != "kube-system"

  # Static uppercase template variables for the Cilium Helm values template.
  # Conditionals and defaults are computed here so the template file remains
  # static and compatible with envsubst or similar local rendering tools.
  cilium_values = {
    COMMON_LABELS             = jsonencode(var.common_labels)
    CLUSTER_NAME              = var.cluster_name
    CLUSTER_ID                = var.cluster_id
    K8S_SERVICE_HOST          = var.k8s_service_host
    K8S_SERVICE_PORT          = var.k8s_service_port
    AKS_BYOCNI_ENABLED        = var.cluster_type == "aks"
    CNI_BIN_PATH              = var.cluster_type == "gke" ? var.gke_cni_bin_path : "/opt/cni/bin"
    ENCRYPTION_ENABLED        = var.encryption_enabled
    ENCRYPTION_TYPE           = var.encryption_type
    EKS_ENI_ENABLED           = var.cluster_type == "eks" && var.eks_eni_enabled
    GKE_ENABLED               = var.cluster_type == "gke"
    HUBBLE_ENABLED            = var.hubble_enabled
    HUBBLE_RELAY_ENABLED      = var.hubble_relay_enabled
    HUBBLE_UI_ENABLED         = var.hubble_ui_enabled
    IPAM_MODE                 = var.cluster_type == "kind" || var.cluster_type == "gke" ? "kubernetes" : "cluster-pool"
    KUBE_PROXY_REPLACEMENT    = var.kube_proxy_replacement
    IPV4_NATIVE_ROUTING_CIDR  = var.ipv4_native_routing_cidr
    POLICY_ENFORCEMENT_MODE   = var.policy_enforcement_mode
    ROUTING_MODE              = var.ipv4_native_routing_cidr != "" ? "native" : ""
    GKE_NODE_INIT_ENABLED     = var.cluster_type == "gke" && var.gke_node_init_enabled
    BANDWIDTH_MANAGER_ENABLED = var.bandwidth_manager_enabled
    BANDWIDTH_MANAGER_BBR     = var.bandwidth_manager_bbr
    HOST_FIREWALL_ENABLED     = var.host_firewall_enabled
    EGRESS_GATEWAY_ENABLED    = var.egress_gateway_enabled
  }
}
