terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "3.2.0"
    }
    kubectl = {
      source = "alekc/kubectl"
      version = "2.2.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "3.1.0"
    }
  }
}
