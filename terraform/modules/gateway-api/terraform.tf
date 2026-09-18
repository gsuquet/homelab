terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.2.0"
    }
  }
  required_version = "> 1.15.0"
}
