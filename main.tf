resource "docker_network" "monitoring" {
  name = var.network_names["monitoring"]
  driver = "bridge"
}

module "cadvisor" {
  source = "./modules/container"
  image = "zcube/cadvisor:latest"
  name = "cadvisor"
  hostname = "cadvisor"
  privileged = true
  ports = [
    {
      "host_port" = 8080
      "container_port" = 8080
    }
  ]
  devices = [
    {
      "host_path" = "/dev/kmsg"
      "container_path" = "/dev/kmsg"
    }
  ]
  volumes = [
    {
      "host_path" = "/"
      "container_path" = "/rootfs"
      "read_only" = true
    },
    {
      "host_path" = "/var/run"
      "container_path" = "/var/run"
    },
    {
      "host_path" = "/sys"
      "container_path" = "/sys"
      "read_only" = true
    },
    {
      "host_path" = "/var/lib/docker"
      "container_path" = "/var/lib/docker"
      "read_only" = true
    },
    {
      "host_path" = "/dev/disk"
      "container_path" = "/dev/disk"
      "read_only" = true
    },
    {
      "host_path" = "/etc/machine-id"
      "container_path" = "/etc/machine-id"
      "read_only" = true
    }
  ]
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
  command = [
    "--docker_only=true",
    "--housekeeping_interval=30s",
  ]
}

module "grafana" {
  source = "./modules/container"
  image = "grafana/grafana:latest"
  name = "grafana"
  hostname = "grafana"
  env = split("\n", file("${path.cwd}/monitoring/grafana/.env"))
  ports = [
    {
      "host_port" = 3000
      "container_port" = 3000
    }
  ]
  volumes = [
    {
      "host_path" = "${path.cwd}/monitoring/grafana/provisioning"
      "container_path" = "/etc/grafana/provisioning"
    }
  ]
  persistent_volumes = {
    "grafana" = {
      "driver" = "local"
      "driver_opts" = {}
      "labels" = {}
      "container_path" = "/var/lib/grafana"
    }
  }
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
}

module "node_exporter" {
  source = "./modules/container"
  image = "prom/node-exporter:latest"
  name = "node_exporter"
  hostname = "node_exporter"
  ports = [
    {
      "host_port" = 9100
      "container_port" = 9100
    }
  ]
  volumes = [
    {
      "host_path" = "/proc"
      "container_path" = "/host/proc"
      "read_only" = true
    },
    {
      "host_path" = "/sys"
      "container_path" = "/host/sys"
      "read_only" = true
    },
    {
      "host_path" = "/"
      "container_path" = "/rootfs"
      "read_only" = true
    },
    {
      "host_path" = "/"
      "container_path" = "/host"
      "read_only" = true
    }
  ]
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
  command = [
    "--path.procfs=/host/proc",
    "--path.sysfs=/host/sys",
    "--path.rootfs=/host",
    "--collector.filesystem.ignored-mount-points",
    "^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"
  ]
}

module "prometheus" {
  source = "./modules/container"
  image = "prom/prometheus:latest"
  name = "prometheus"
  hostname = "prometheus"
  ports = [
    {
      "host_port" = 9090
      "container_port" = 9090
    }
  ]
  volumes = [
    {
      "host_path" = "${path.cwd}/monitoring/prometheus/prometheus.yml"
      "container_path" = "/etc/prometheus/prometheus.yml"
    }
  ]
  persistent_volumes = {
    "prometheus" = {
      "driver" = "local"
      "driver_opts" = {}
      "labels" = {}
      "container_path" = "/prometheus"
    }
  }
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
  healthcheck_cmd = [
    "CMD",
    "wget",
    "--no-verbose",
    "--tries=3",
    "--spider",
    "http://localhost:9090/"
  ]
  healthcheck_params = {
    "interval" = "30s"
    "timeout" = "30s"
    "retries" = "3"
    "start_period" = "30s"
  }
  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=200h",
    "--web.console.libraries=/etc/prometheus/console_libraries",
    "--web.console.templates=/etc/prometheus/consoles"
  ]
}

module "dashboard" {
  source = "./modules/container"
  image = "lissy93/dashy:latest"
  name = "dashboard"
  hostname = "dashboard"
  ports = [
    {
      "host_port" = 4000
      "container_port" = 80
    }
  ]
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
}

module "portainer" {
  source = "./modules/container"
  image = "portainer/portainer-ce:alpine"
  name = "portainer"
  hostname = "portainer"
  ports = [
    {
      "host_port" = 9000
      "container_port" = 9000
    }
  ]
  volumes = [
    {
      "host_path" = "/var/run/docker.sock"
      "container_path" = "/var/run/docker.sock"
      "read_only" = true
    }
  ]
  persistent_volumes = {
    "portainer" = {
      "driver" = "local"
      "driver_opts" = {}
      "labels" = {}
      "container_path" = "/data"
    }
  }
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
  healthcheck_cmd = [
    "CMD",
    "wget",
    "--no-verbose",
    "--tries=3",
    "--spider",
    "http://127.0.0.1:9000/api/system/status"
  ]
  healthcheck_params = {
    "interval" = "30s"
    "timeout" = "30s"
    "retries" = "3"
    "start_period" = "30s"
  }
}

module "dhcphelper" {
  source = "./modules/container"
  image = "homeall/dhcphelper:latest"
  name = "dhcphelper"
  hostname = "dhcphelper"
  env = [ "TZ=Europe/Berlin" ]
}

module "pihole" {
  source = "./modules/container"
  image = "pihole/pihole:latest"
  name = "pihole"
  hostname = "pihole"
  env = [
    "TZ=Europe/Berlin",
    "WEBPASSWORD=${var.pihole_password}",
    "DNS1=1.1.1.3",
    "DNS2=127.0.0.1"
  ]
  ports = [
    {
      "host_port" = 53
      "container_port" = 53
      "protocol" = "udp"
    },
    {
      "host_port" = 53
      "container_port" = 53
      "protocol" = "tcp"
    },
    {
      "host_port" = 67
      "container_port" = 67
      "protocol" = "udp"
    },
    {
      "host_port" = 80
      "container_port" = 80
    },
    {
      "host_port" = 443
      "container_port" = 443
    }
  ]
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
}

module "wireguard" {
  source = "./modules/container"
  image = "linuxserver/wireguard:latest"
  name = "wireguard"
  hostname = "wireguard"
  ports = [
    {
      "host_port" = 51820
      "container_port" = 51820
      "protocol" = "udp"
    }
  ]
  volumes = [
    {
      "host_path" = "${path.cwd}/security/wireguard"
      "container_path" = "/config"
    }
  ]
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
}
