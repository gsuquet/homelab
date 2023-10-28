variable "image" {
  description = "The name of the image to use"
  type = string
}

variable "keep_image_locally" {
  description = "Whether to keep the image locally"
  type = bool
  default = false
}

variable "name" {
  description = "The name of the container"
  type = string
}

variable "hostname" {
  description = "The hostname of the container"
  type = string
}

variable "restart_policy" {
  description = "The restart policy of the container"
  type = string
  default = "unless-stopped"
}

variable "privileged" {
  description = "Whether to run the container in privileged mode"
  type = bool
  default = false
}

variable "env" {
  description = "The environment variables to set"
  type = list(string)
  default = []
}

variable "ports" {
  description = "The ports to expose"
  type = list(any)
  default = []
}

variable "devices" {
  description = "The devices to mount"
  type = list(any)
  default = []

}

variable "volumes" {
  description = "The volumes to mount"
  type = list(any)
  default = []

}

variable "persistent_volumes" {
  description = "The persistent volumes to create and mount"
  type = map(any)
  default = {}
}

variable "networks" {
  description = "The networks to connect to"
  type = list(any)
  default = []
}

variable "healthcheck_cmd" {
  description = "The command to run to check the health of the container"
  type = list(string)
  default = []
}

variable "healthcheck_params" {
  description = "The parameters to pass to the healthcheck command"
  type = map(string)
  default = {}
}

variable "command" {
  description = "The commands and flags to run the container with"
  type = list(string)
  default = []
}

variable "labels" {
  description = "The labels to set"
  type = map(string)
  default = {}
}
