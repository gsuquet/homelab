terraform {
  required_version = "> 1.15.0"

  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.2.0"
    }
  }
}
