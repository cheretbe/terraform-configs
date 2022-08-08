terraform {
  required_providers {
    # https://registry.terraform.io/providers/kreuzwerker/docker/latest
    docker = {
      source  = "kreuzwerker/docker"
      # version = "2.20.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_image" "ubuntu_ansible" {
  name = "ubuntu_ansible"
  build {
    path = "${path.module}"
    tag  = ["ubuntu_ansible:latest"]
  }
  force_remove = true
}

resource "docker_network" "ansible_controller_network" {
  count = var.docker_network == null ? 1 : 0
  name = "ansible_controller_network"
  attachable = true
  driver = "bridge"
}

resource "docker_container" "ansible_controller" {
  image = docker_image.ubuntu_ansible.latest
  name  = "ansible-controller"
  restart = "on-failure"
  # https://stackoverflow.com/questions/21553353/what-is-the-difference-between-cmd-and-entrypoint-in-a-dockerfile
  command = [ "/entry_point_command.sh" ]

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
