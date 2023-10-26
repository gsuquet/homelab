variable "container_names" {
  description = "Container names"
  type = map(string)
  default = {
    "caddy" = "caddy",
    "cadvisor" = "cadvisor",
    "dashboard" = "dashboard",
    "dhcphelper" = "dhcphelper",
    "grafana" = "grafana",
    "node-exporter" = "node-exporter",
    "pihole" = "pihole",
    "portainer" = "portainer",
    "prometheus" = "prometheus",
    "wireguard" = "wireguard",
    "wireguard-ui" = "wireguard-ui",
  }
}

variable "container_hostnames" {
  description = "Container hostnames"
  type = map(string)
  default = {
    "caddy" = "caddy",
    "cadvisor" = "cadvisor",
    "dashboard" = "dashboard",
    "dhcphelper" = "dhcphelper",
    "grafana" = "grafana",
    "node-exporter" = "node-exporter",
    "pihole" = "pihole",
    "portainer" = "portainer",
    "prometheus" = "prometheus",
    "wireguard" = "wireguard",
    "wireguard-ui" = "wireguard-ui",
  }
}

variable "network_names" {
  description = "Docker network names"
  type = map(string)
  default = {
    "monitoring" = "monitoring",
  }
}

variable "pihole_password" {
  description = "Pi-hole password"
  type = string
  sensitive = true
  default = "changeme"
}
