## Container Module

This module is used to create a container along with the resources required to run it.

### Properties

The `container` module has the following variables:

- `image`: a string representing the name of the container image to use
- `keep_image_locally`: a boolean indicating whether to keep the container image locally
- `name`: a string representing the name of the container
- `hostname`: a string representing the hostname of the container
- `restart_policy`: a string representing the restart policy for the container
- `privileged`: a boolean indicating whether to run the container in privileged mode
- `env`: a list of strings representing environment variables to set in the container
- `ports`: a list of objects representing port mappings for the container
- `devices`: a list of objects representing device mappings for the container
- `volumes`: a list of objects representing volume mappings for the container
- `persistent_volumes`: a list of objects representing persistent volume mappings for the container
- `networks`: a list of objects representing network settings for the container
- `healthcheck_cmd`: a list of string representing the command to use for the healthcheck
- `healthcheck_params`: a map of strings representing the parameters to use for the healthcheck
- `command`: a list of strings representing the command to run in the container
- `labels`: a map of strings representing labels to apply to the container

### Example Usage

```terraform
module "container" {
  source = "./modules/container"
  image = "nginx:latest"
  keep_image_locally = false
  name = "example"
  hostname = "example"
  restart_policy = "always"
  privileged = false
  env = ["VAR=value"]
  ports = [
    {
      internal = 80
      external = 8080
      protocol = "tcp"
    }
  ]
  devices = [
    {
      host_path = "/dev/sda"
      container_path = "/dev/xvda"
      permissions = "rw"
    }
  ]
  volumes = [
    {
      container_path = "/data"
      host_path = "/mnt/data"
      read_only = true
    }
  ]
  persistent_volumes = [
    data_volume = {
      driver = "local"
      driver_opts = {}
      labels = {}
      container_path = "/data"
    }
  ]
  networks = [
    {
      name = "network1"
      aliases = ["alias1", "alias2"]
      ipv4_address = "192.168.1.1"
      ipv6_address = "2001:db8::1"
    }
  ]
  healthcheck_cmd = ["CMD", "curl", "-f", "http://localhost/"]
  healthcheck_params = {
    interval = "30s"
    timeout = "10s"
    retries = 3
    start_period = "40s"
  }
  command = ["nginx", "-g", "daemon off;"]
  labels = {
    "key1" = "value1"
    "key2" = "value2"
  }
}
