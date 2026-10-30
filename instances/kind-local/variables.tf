variable "extra_ca_certificate_paths" {
  description = "PEM files of extra CAs that the Kind nodes must trust, for example the CA of a TLS-inspecting proxy. Set it in a gitignored local.auto.tfvars on the machine that needs it."
  type        = list(string)
  default     = []
}
