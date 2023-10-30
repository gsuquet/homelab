variable "container_names" {
  description = "Container names"
  type        = map(string)
  default = {
    "cadvisor"      = "cadvisor",
    "dashboard"     = "dashboard",
    "dhcphelper"    = "dhcphelper",
    "grafana"       = "grafana",
    "node-exporter" = "node-exporter",
    "pihole"        = "pihole",
    "portainer"     = "portainer",
    "prometheus"    = "prometheus",
    "wireguard"     = "wireguard",
    "wireguard-ui"  = "wireguard-ui",
  }
}

variable "container_hostnames" {
  description = "Container hostnames"
  type        = map(string)
  default = {
    "cadvisor"      = "cadvisor",
    "dashboard"     = "dashboard",
    "dhcphelper"    = "dhcphelper",
    "grafana"       = "grafana",
    "node-exporter" = "node-exporter",
    "pihole"        = "pihole",
    "portainer"     = "portainer",
    "prometheus"    = "prometheus",
    "wireguard"     = "wireguard",
    "wireguard-ui"  = "wireguard-ui",
  }
}

variable "images" {
  description = "Container images"
  type        = map(string)
  default = {
    "cadvisor"      = "zcube/cadvisor:latest",
    "dashboard"     = "lissy93/dashy:latest",
    "dhcphelper"    = "homeall/dhcphelper:latest",
    "grafana"       = "grafana/grafana:latest",
    "node-exporter" = "prom/node-exporter:latest",
    "pihole"        = "pihole/pihole:latest",
    "portainer"     = "portainer/portainer-ce:alpine",
    "prometheus"    = "prom/prometheus:latest",
    "wireguard"     = "linuxserver/wireguard:latest",
  }
}

variable "network_names" {
  description = "Docker network names"
  type        = map(string)
  default = {
    "monitoring" = "monitoring",
  }
}

variable "pihole_password" {
  description = "Pi-hole password"
  type        = string
  sensitive   = true
  default     = "changeme"
}
