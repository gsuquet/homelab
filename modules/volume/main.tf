resource "docker_volume" "volume" {
  name = var.name
  driver = var.driver
  driver_opts = var.driver_opts

  dynamic "labels" {
    for_each = var.labels != "" ? [] : [var.labels]
    content {
      label = labels.key
      value = labels.value
    }
  }
}
