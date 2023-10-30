variable "name" {
  description = "Volume name"
  type        = string
  default     = ""
}

variable "driver" {
  description = "Type of volume driver"
  type        = string
  default     = "local"
}

variable "driver_opts" {
  description = "Driver options"
  type        = map(string)
  default     = {}
}

variable "labels" {
  description = "The labels to set"
  type        = map(string)
  default     = {}
}
