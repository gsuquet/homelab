variable "name" {
  description = "Name of the example resource. Use lowercase letters, digits and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.name))
    error_message = "The name must use lowercase letters, digits and hyphens."
  }
}
