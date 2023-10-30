output "id" {
  description = "Volume ID"
  value       = docker_volume.volume.id
}

output "name" {
  description = "Volume name"
  value       = docker_volume.volume.name
}

output "mountpoint" {
  description = "Volume mountpoint"
  value       = docker_volume.volume.mountpoint
}

output "driver" {
  description = "Volume driver"
  value       = docker_volume.volume.driver
}
