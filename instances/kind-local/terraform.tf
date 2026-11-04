terraform {
  required_version = "> 1.15.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.13.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.1.0"
    }
  }
}
