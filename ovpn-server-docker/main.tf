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
  devices { host_path = "/dev/net/tun" }
  capabilities {
    add = ["CAP_NET_ADMIN", "CAP_SYS_ADMIN"]
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

# TODO: Add router_wan_if_mac_addr parameter to router Ansible role and
#       use docker_container.ovpn_server.ip_address
# This external datasource example should go to notes after that
# https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/data_source
# [!] Even though the doc for external datasource states that "program must then
#     produce a valid JSON object on stdout", it actually supports only limited
#     subset of JSON (no arrays etc.). That's why jq is used here
#     See:
#     https://github.com/hashicorp/terraform/issues/12249
#     https://github.com/hashicorp/terraform/issues/12256
data "external" "server_mac" {
  depends_on=[module.ovpn_server_user]

  program = [
    "bash", "-c",
    "docker inspect -f '{{json .NetworkSettings.Networks.terraform_ovpn_network}}' terraform-docker-ovpn-server | jq  -j '{mac_addr: .MacAddress}'"
  ]
}

module "ovpn_server_user" {
  source = "../modules/vagrant-user"

  container_name = "${docker_container.ovpn_server.name}"
}

module "ovpn_server_ansible" {
  source = "../modules/ansible-controller"

  depends_on=[module.ovpn_server_user]
  connection = local.server_ssh_connection
}


resource "null_resource" "certificates" {
  connection {
    type        = "ssh"
    host        = local.server_ssh_connection.host
    user        = local.server_ssh_connection.user
    private_key = local.server_ssh_connection.private_key
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /home/vagrant/ansible-data"]
  }

  provisioner "file" {
    source = "${path.module}/local/ca.crt"
    destination = "/home/vagrant/ansible-data/ca.crt"
  }

  provisioner "file" {
    source = "${path.module}/local/server.crt"
    destination = "/home/vagrant/ansible-data/server.crt"
  }

  provisioner "file" {
    source = "${path.module}/local/server.key"
    destination = "/home/vagrant/ansible-data/server.key"
  }

  provisioner "file" {
    source = "${path.module}/local/ta.key"
    destination = "/home/vagrant/ansible-data/ta.key"
  }
}

module "ovpn_server_provision" {
  source = "../modules/ansible-local-provision"

  depends_on=[module.ovpn_server_ansible]
  connection = local.server_ssh_connection
  playbook = "${path.module}/provision/server_provision.yml"
  extra_vars = {
    ovpn_server_ca_cert  = "/home/vagrant/ansible-data/ca.crt"
    ovpn_server_cert     = "/home/vagrant/ansible-data/server.crt"
    ovpn_server_key      = "/home/vagrant/ansible-data/server.key"
    ovpn_server_ta_key   = "/home/vagrant/ansible-data/ta.key"
    ovpn_server_dns_name = "vpn.example.com"
    router_wan_if_mac_addr = "${data.external.server_mac.result.mac_addr}"
    router_lan_if_name   = "tun0"
    router_allow_wan_ssh = true
  }
}
