terraform {
  required_providers {
    # https://registry.terraform.io/providers/kreuzwerker/docker/latest
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.15.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Pulls the image
resource "docker_image" "ubuntu" {
  name = "geerlingguy/docker-ubuntu2004-ansible"
  keep_locally = true
}

resource "docker_network" "ansible_controller_network" {
  count = var.docker_network == null ? 1 : 0
  name = "ansible_controller_network"
  attachable = true
  driver = "bridge"
}

resource "docker_container" "ansible_controller" {
  image = docker_image.ubuntu.latest
  name  = "ansible-controller"
  restart = "on-failure"
  command = [ "/usr/lib/systemd/systemd" ]

  networks_advanced {
    name = var.docker_network == null ? docker_network.ansible_controller_network[0].name : var.docker_network.name
  }

  volumes {
    host_path      = "/sys/fs/cgroup"
    container_path = "/sys/fs/cgroup"
    read_only      = true
  }
  volumes {
    host_path      = "/sys/fs/fuse"
    container_path = "/sys/fs/fuse"
    read_only      = true
  }
  tmpfs = {
    "/run" = "",
    "/run/lock" = "",
    "/tmp:exec" = ""
  }
}

output "container" {
  value = docker_container.ansible_controller
}
