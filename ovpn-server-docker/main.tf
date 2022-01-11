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

resource "docker_network" "terraform_ovpn_network" {
  name = "terraform_ovpn_network"
  attachable = true
  driver = "bridge"
}

# Pulls the image
resource "docker_image" "ubuntu" {
  name = "geerlingguy/docker-ubuntu2004-ansible"
  keep_locally = true
}

resource "docker_container" "ovpn_server" {
  image = docker_image.ubuntu.latest
  name  = "terraform-docker-ovpn-server"
  restart = "on-failure"
  # publish_all_ports = true
  command = [ "/usr/lib/systemd/systemd" ]

  networks_advanced {
    name = "${docker_network.terraform_ovpn_network.name}"
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

# resource "docker_container" "foo2" {
#   image = docker_image.ubuntu.latest
#   name  = "terraform-docker-test-2"
#   restart = "on-failure"
#   # publish_all_ports = true
#   command = [ "/usr/lib/systemd/systemd" ]

#   networks_advanced {
#     name = "${docker_network.terraform_network.name}"
#   }

#   volumes {
#     host_path      = "/sys/fs/cgroup"
#     container_path = "/sys/fs/cgroup"
#     read_only      = true
#   }
#   volumes {
#     host_path      = "/sys/fs/fuse"
#     container_path = "/sys/fs/fuse"
#     read_only      = true
#   }
#   tmpfs = {
#     "/run" = "",
#     "/run/lock" = "",
#     "/tmp:exec" = ""
#   }
# }

output "ovpn_server_ip" {
  value = "${docker_container.ovpn_server.ip_address}"
}

# output "IP2" {
#   value = "${docker_container.foo2.ip_address}"
# }

locals {
  server_ssh_connection = {
    host        = "${docker_container.ovpn_server.ip_address}"
    user        = "vagrant"
    private_key = file("~/.vagrant.d/insecure_private_key")
  }
}

module "ovpn_server_user" {
  source = "../modules/vagrant-user"

  container_name = "${docker_container.ovpn_server.name}"
}

module "ovpn_server_ansible" {
  source = "../modules/ansible-controller"

  connection = local.server_ssh_connection
}

module "ovpn_server_provision" {
  source = "../modules/ansible-local-provision"

  connection = local.server_ssh_connection
  playbook = "${path.module}/provision/server_provision.yml"
  extra_vars = {
    var1 = "dummy"
  }
}
