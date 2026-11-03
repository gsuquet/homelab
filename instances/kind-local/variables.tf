variable "extra_ca_certificate_paths" {
  description = "PEM files of extra CAs that the Kind nodes must trust, for example the CA of a TLS-inspecting proxy. Set it in a gitignored local.auto.tfvars on the machine that needs it."
  type        = list(string)
  default     = []
}

# TODO: the host names depend on the OIDC issuer decision of the OpenChoreo plan
# (a spike researches it). Change the default when the decision is made.
variable "openchoreo_hostnames" {
  description = "Host names that CoreDNS sends to the Gateway of the OpenChoreo control plane, so that pods and the browser use the same OIDC issuer name."
  type        = list(string)
  default     = ["openchoreo.localhost", "thunder.openchoreo.localhost"]
}

# TODO: the Service name is a guess until the control plane component exists
# (plan step 4). Until then the host names resolve to NXDOMAIN in the cluster.
variable "openchoreo_gateway_service" {
  description = "Fully qualified name of the Service of the control plane kgateway Gateway. CoreDNS rewrites the OpenChoreo host names to it."
  type        = string
  default     = "gateway-default.openchoreo-control-plane.svc.cluster.local"
}
