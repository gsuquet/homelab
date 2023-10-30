resource "docker_network" "monitoring" {
  name   = var.network_names["monitoring"]
  driver = "bridge"
}

module "cadvisor" {
  source     = "./modules/container"
  image      = var.images["cadvisor"]
  name       = var.container_names["cadvisor"]
  hostname   = var.container_hostnames["cadvisor"]
  privileged = true
  ports = [
    {
      "host_port"      = 8080
      "container_port" = 8080
    }
  ]
  devices = [
    {
      "host_path"      = "/dev/kmsg"
      "container_path" = "/dev/kmsg"
    }
  ]
  volumes = [
    {
      "host_path"      = "/"
      "container_path" = "/rootfs"
      "read_only"      = true
    },
    {
      "host_path"      = "/var/run"
      "container_path" = "/var/run"
    },
    {
      "host_path"      = "/sys"
      "container_path" = "/sys"
      "read_only"      = true
    },
    {
      "host_path"      = "/var/lib/docker"
      "container_path" = "/var/lib/docker"
      "read_only"      = true
    },
    {
      "host_path"      = "/dev/disk"
      "container_path" = "/dev/disk"
      "read_only"      = true
    },
    {
      "host_path"      = "/etc/machine-id"
      "container_path" = "/etc/machine-id"
      "read_only"      = true
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
  source   = "./modules/container"
  image    = var.images["grafana"]
  name     = var.container_names["grafana"]
  hostname = var.container_hostnames["grafana"]
  env      = split("\n", file("${path.cwd}/monitoring/grafana/.env"))
  ports = [
    {
      "host_port"      = 3000
      "container_port" = 3000
    }
  ]
  volumes = [
    {
      "host_path"      = "${path.cwd}/monitoring/grafana/provisioning"
      "container_path" = "/etc/grafana/provisioning"
    }
  ]
  persistent_volumes = {
    "grafana" = {
      "driver"         = "local"
      "driver_opts"    = {}
      "labels"         = {}
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
  source   = "./modules/container"
  image    = var.images["node-exporter"]
  name     = var.container_names["node-exporter"]
  hostname = var.container_hostnames["node-exporter"]
  ports = [
    {
      "host_port"      = 9100
      "container_port" = 9100
    }
  ]
  volumes = [
    {
      "host_path"      = "/proc"
      "container_path" = "/host/proc"
      "read_only"      = true
    },
    {
      "host_path"      = "/sys"
      "container_path" = "/host/sys"
      "read_only"      = true
    },
    {
      "host_path"      = "/"
      "container_path" = "/rootfs"
      "read_only"      = true
    },
    {
      "host_path"      = "/"
      "container_path" = "/host"
      "read_only"      = true
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
  source   = "./modules/container"
  image    = var.images["prometheus"]
  name     = var.container_names["prometheus"]
  hostname = var.container_hostnames["prometheus"]
  ports = [
    {
      "host_port"      = 9090
      "container_port" = 9090
    }
  ]
  volumes = [
    {
      "host_path"      = "${path.cwd}/monitoring/prometheus/prometheus.yml"
      "container_path" = "/etc/prometheus/prometheus.yml"
    }
  ]
  persistent_volumes = {
    "prometheus" = {
      "driver"         = "local"
      "driver_opts"    = {}
      "labels"         = {}
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
    "interval"     = "30s"
    "timeout"      = "30s"
    "retries"      = "3"
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
  source   = "./modules/container"
  image    = var.images["dashboard"]
  name     = var.container_names["dashboard"]
  hostname = var.container_hostnames["dashboard"]
  ports = [
    {
      "host_port"      = 4000
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
  source   = "./modules/container"
  image    = var.images["portainer"]
  name     = var.container_names["portainer"]
  hostname = var.container_hostnames["portainer"]
  ports = [
    {
      "host_port"      = 9000
      "container_port" = 9000
    }
  ]
  volumes = [
    {
      "host_path"      = "/var/run/docker.sock"
      "container_path" = "/var/run/docker.sock"
      "read_only"      = true
    }
  ]
  persistent_volumes = {
    "portainer" = {
      "driver"         = "local"
      "driver_opts"    = {}
      "labels"         = {}
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
    "interval"     = "30s"
    "timeout"      = "30s"
    "retries"      = "3"
    "start_period" = "30s"
  }
}

module "dhcphelper" {
  source   = "./modules/container"
  image    = var.images["dhcphelper"]
  name     = var.container_names["dhcphelper"]
  hostname = var.container_hostnames["dhcphelper"]
  env      = ["TZ=Europe/Berlin"]
}

module "pihole" {
  source   = "./modules/container"
  image    = var.images["pihole"]
  name     = var.container_names["pihole"]
  hostname = var.container_hostnames["pihole"]
  env = [
    "TZ=Europe/Berlin",
    "WEBPASSWORD=${var.pihole_password}",
    "DNS1=1.1.1.3",
    "DNS2=127.0.0.1"
  ]
  ports = [
    {
      "host_port"      = 53
      "container_port" = 53
      "protocol"       = "udp"
    },
    {
      "host_port"      = 53
      "container_port" = 53
      "protocol"       = "tcp"
    },
    {
      "host_port"      = 67
      "container_port" = 67
      "protocol"       = "udp"
    },
    {
      "host_port"      = 80
      "container_port" = 80
    },
    {
      "host_port"      = 443
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
  source   = "./modules/container"
  image    = var.images["wireguard"]
  name     = var.container_names["wireguard"]
  hostname = var.container_hostnames["wireguard"]
  ports = [
    {
      "host_port"      = 51820
      "container_port" = 51820
      "protocol"       = "udp"
    }
  ]
  volumes = [
    {
      "host_path"      = "${path.cwd}/security/wireguard"
      "container_path" = "/config"
    }
  ]
  networks = [
    {
      name = docker_network.monitoring.name
    }
  ]
}
