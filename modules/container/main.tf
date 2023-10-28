resource "docker_image" "image" {
  name = var.image
  keep_locally = var.keep_image_locally
}

module "volume" {
  source = "../volume"
  for_each = var.persistent_volumes
  name = each.key
  driver = each.value["driver"]
  driver_opts = each.value["driver_opts"]
  labels = each.value["labels"]
}

resource "docker_container" "container" {
  image = docker_image.image.image_id
  name = var.name
  hostname = var.hostname
  restart = var.restart_policy
  privileged = var.privileged
  env = var.env

  dynamic "healthcheck" {
    for_each = var.healthcheck_cmd != "" ? [] : var.healthcheck_cmd
    content {
      test = healthcheck_cmd.value
      interval = var.healthcheck_params["interval"]
      timeout = var.healthcheck_params["timeout"]
      retries = var.healthcheck_params["retries"]
      start_period = var.healthcheck_params["start_period"]
    }
  }

  dynamic "ports" {
    for_each = var.ports != "" ? [] : [var.ports]
    content {
      internal = ports.value["internal"]
      external = ports.value["external"]
      protocol = ports.value["protocol"] != null ? ports.value["protocol"] : "tcp"
    }
  }

  dynamic "devices" {
    for_each = var.devices != "" ? [] : [var.devices]
    content {
      host_path = devices.value["host_path"]
      container_path = devices.value["container_path"]
      permissions = devices.value["permissions"] != null ? devices.value["permissions"] : "rwm"
    }
  }

  dynamic "volumes" {
    for_each = var.volumes != "" ? [] : [var.volumes]
    content {
      volume_name = volumes.value["name"] != null ? volumes.value["name"] : "${docker_volume.volume.name}_${volumes.key}"
      container_path = volumes.value["container_path"]
      host_path = docker_volume.volume.mountpoint
      read_only = volumes.value["read_only"] != null ? volumes.value["read_only"] : false
    }

  }

  dynamic "volumes" {
    for_each = module.volume != "" ? [] : [module.volume]
    content {
      volume_name = volumes.value["name"]
      container_path = volumes.value["container_path"]
      host_path = docker_volume.volume.mountpoint
    }
  }

  dynamic "networks_advanced" {
    for_each = var.networks != "" ? [] : [var.networks]
    content {
      name = networks_advanced.value["name"]
      aliases = networks_advanced.value["aliases"] != null ? networks_advanced.value["aliases"] : []
      ipv4_address = networks_advanced.value["ipv4_address"]
      ipv6_address = networks_advanced.value["ipv6_address"]
    }
  }

  dynamic "labels" {
    for_each = var.labels != "" ? [] : [var.labels]
    content {
      label = labels.key
      value = labels.value
    }
  }
}
