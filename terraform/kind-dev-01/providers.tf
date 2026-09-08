provider "kind" {}

provider "kubernetes" {
  config_path = module.kind_cluster.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = module.kind_cluster.kubeconfig_path
  }
}
