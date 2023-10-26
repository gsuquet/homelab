resource "docker_network" "monitoring" {
  name = var.network_names["monitoring"]
  driver = "bridge"
}

resource "docker_image" "cadvisor" {
  name = "gcr.io/cadvisor/cadvisor:latest"
  keep_locally = false
}

resource "docker_container" "cadvisor" {
  image = docker_image.cadvisor.image_id
  name = var.container_names["cadvisor"]
  hostname = var.container_hostnames["cadvisor"]
  restart = "unless-stopped"
  privileged = true
  ports {
    internal = 8080
    external = 8080
  }
  devices {
    host_path = "/dev/kmsg"
    container_path = "/dev/kmsg"
  }
  volumes {
    container_path = "/rootfs"
    host_path = "/"
    read_only = true
  }
  volumes {
    container_path = "/var/run"
    host_path = "/var/run"
  }
  volumes {
    container_path = "/sys"
    host_path = "/sys"
    read_only = true
  }
  volumes {
    container_path = "/var/lib/docker"
    host_path = "/var/lib/docker"
    read_only = true
  }
  volumes {
    container_path = "/dev/disk"
    host_path = "/dev/disk"
    read_only = true
  }
  volumes {
    container_path = "/etc/machine-id"
    host_path = "/etc/machine-id"
    read_only = true
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
}

resource "docker_image" "dashboard" {
  name = "lissy93/dashy:latest"
  keep_locally = false
}

resource "docker_container" "dashboard" {
  image = docker_image.dashboard.image_id
  name = var.container_names["dashboard"]
  hostname = var.container_hostnames["dashboard"]
  restart = "unless-stopped"
  ports {
    internal = 80
    external = 4000
  }
}

resource "docker_image" "grafana" {
  name = "grafana/grafana:latest"
  keep_locally = false
}

resource "docker_volume" "grafana" {
  name = "${var.container_names["grafana"]}_data"
}

resource "docker_container" "grafana" {
  image = docker_image.grafana.image_id
  name = var.container_names["grafana"]
  hostname = var.container_hostnames["grafana"]
  restart = "unless-stopped"
  ports {
    internal = 3000
    external = 3000
  }
  volumes {
    volume_name = docker_volume.grafana.name
    container_path = "/var/lib/grafana"
    host_path = docker_volume.grafana.mountpoint
  }
  volumes {
    container_path = "/etc/grafana/provisioning"
    host_path = "${path.cwd}/monitoring/grafana/provisioning"
  }
  env = split("\n", file("./monitoring/grafana/.env"))
  networks_advanced {
    name = docker_network.monitoring.name
  }
}

resource "docker_image" "node_exporter" {
  name = "prom/node-exporter:latest"
  keep_locally = false
}

resource "docker_container" "node_exporter" {
  image = docker_image.node_exporter.image_id
  name = var.container_names["node-exporter"]
  hostname = var.container_hostnames["node-exporter"]
  restart = "unless-stopped"
  ports {
    internal = 9100
    external = 9100
  }
  volumes {
    container_path = "/host/proc"
    host_path = "/proc"
    read_only = true
  }
  volumes {
    container_path = "/host/sys"
    host_path = "/sys"
    read_only = true
  }
  volumes {
    container_path = "/rootfs"
    host_path = "/"
    read_only = true
  }
  volumes {
    container_path = "/host"
    host_path = "/"
    read_only = true
  }
  command = [
    "--path.procfs=/host/proc",
    "--path.sysfs=/host/sys",
    "--path.rootfs=/host",
    "--collector.filesystem.ignored-mount-points",
    "^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"
  ]
  networks_advanced {
    name = docker_network.monitoring.name
  }
}

resource "docker_image" "pihole" {
  name = "pihole/pihole:latest"
  keep_locally = false
}

resource "docker_container" "pihole" {
  image = docker_image.pihole.image_id
  name = var.container_names["pihole"]
  hostname = var.container_hostnames["pihole"]
  restart = "unless-stopped"
  ports {
    internal = 53
    external = 53
  }
  ports {
    internal = 53
    external = 53
    protocol = "udp"
  }
  ports {
    internal = 67
    external = 67
    protocol = "udp"
  }
  ports {
    internal = 80
    external = 80
  }
  env = [
    "TZ=Europe/Berlin",
    "WEBPASSWORD=${var.pihole_password}",
    "DNS1=1.1.1.3",
    "DNS2=127.0.0.1"
  ]
}

resource "docker_image" "portainer" {
  name = "portainer/portainer-ce:alpine"
  keep_locally = false
}

resource "docker_volume" "portainer" {
  name = "${var.container_names["portainer"]}_data"
}

resource "docker_container" "portainer" {
  image = docker_image.portainer.image_id
  name = var.container_names["portainer"]
  hostname = var.container_hostnames["portainer"]
  restart = "unless-stopped"
  ports {
    internal = 9000
    external = 9000
  }
  volumes {
    container_path = "/var/run/docker.sock"
    host_path = "/var/run/docker.sock"
    read_only = true
  }
  volumes {
    volume_name = docker_volume.portainer.name
    container_path = "/data"
    host_path = docker_volume.portainer.mountpoint
  }
  healthcheck {
    test = ["CMD", "wget", "--no-verbose", "--tries=3", "--spider", "http://127.0.0.1:9000/api/system/status"]
    interval = "30s"
    timeout = "30s"
    retries = 3
    start_period = "30s"
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
}

resource "docker_image" "prometheus" {
  name = "prom/prometheus:latest"
  keep_locally = false
}

resource "docker_volume" "prometheus" {
  name = "${var.container_names["prometheus"]}_data"
}

resource "docker_container" "prometheus" {
  image = docker_image.prometheus.image_id
  name = var.container_names["prometheus"]
  hostname = var.container_hostnames["prometheus"]
  restart = "unless-stopped"
  ports {
    internal = 9090
    external = 9090
  }
  volumes {
    container_path = "/etc/prometheus/prometheus.yml"
    host_path = "${path.cwd}/monitoring/prometheus/prometheus.yml"
  }
  volumes {
    volume_name = docker_volume.prometheus.name
    container_path = "/prometheus"
    host_path = docker_volume.prometheus.mountpoint
  }
  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=200h",
    "--web.console.libraries=/etc/prometheus/console_libraries",
    "--web.console.templates=/etc/prometheus/consoles"
  ]
  depends_on = [
    docker_container.node_exporter,
    docker_image.cadvisor
  ]
  healthcheck {
    test = ["CMD", "wget", "--no-verbose", "--tries=3", "--spider", "http://localhost:9090/"]
    interval = "30s"
    timeout = "30s"
    retries = 3
    start_period = "30s"
  }
  networks_advanced {
    name = docker_network.monitoring.name
  }
}

resource "docker_image" "wireguard" {
  name = "linuxserver/wireguard:latest"
  keep_locally = false
}

resource "docker_container" "wireguard" {
  image = docker_image.wireguard.image_id
  name = var.container_names["wireguard"]
  hostname = var.container_hostnames["wireguard"]
  restart = "unless-stopped"
  ports {
    internal = 51820
    external = 51820
  }
  volumes {
    container_path = "/config"
    host_path = "${path.cwd}/security/wireguard"
  }
}
