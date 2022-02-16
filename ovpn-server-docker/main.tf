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
  devices {
    host_path      = "/dev/net/tun"
    container_path = "/dev/net/tun"
    permissions    = "rwm"
  }
  capabilities {
    add = ["CAP_NET_ADMIN", "CAP_SYS_ADMIN"]
  }
}

resource "docker_container" "ansible_controller" {
  image = docker_image.ubuntu.latest
  name  = "ansible-controller"
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

output "ovpn_server_ip" {
  value = "${docker_container.ovpn_server.ip_address}"
}

locals {
  ansible_controller_ssh_connection = {
    host        = "${docker_container.ansible_controller.ip_address}"
    user        = "vagrant"
    private_key = file("~/.vagrant.d/insecure_private_key")
  }
  server_ssh_connection = {
    host        = "${docker_container.ovpn_server.ip_address}"
    user        = "vagrant"
    private_key = file("~/.vagrant.d/insecure_private_key")
  }
}

module "ansible_controller_user" {
  source = "../modules/vagrant-user"

  container_name = "${docker_container.ansible_controller.name}"
}

module "ovpn_server_user" {
  source = "../modules/vagrant-user"

  container_name = "${docker_container.ovpn_server.name}"
}

resource "null_resource" "certificates" {
  depends_on=[module.ansible_controller_user, module.ovpn_server_user]

  connection {
    type        = "ssh"
    host        = local.ansible_controller_ssh_connection.host
    user        = local.ansible_controller_ssh_connection.user
    private_key = local.ansible_controller_ssh_connection.private_key
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
  source = "../modules/ansible-provision"

  # depends_on=[module.ansible_controller_user, module.ovpn_server_user]
  depends_on=[resource.null_resource.certificates]
  controller_connection = local.ansible_controller_ssh_connection
  server_connection = local.server_ssh_connection
  playbook = "${path.module}/provision/server_provision.yml"
  extra_vars = {
    ovpn_server_ca_cert  = "/home/vagrant/ansible-data/ca.crt"
    ovpn_server_cert     = "/home/vagrant/ansible-data/server.crt"
    ovpn_server_key      = "/home/vagrant/ansible-data/server.key"
    ovpn_server_ta_key   = "/home/vagrant/ansible-data/ta.key"
    ovpn_server_dns_name = "vpn.example.com"
    router_wan_if_ip_addr = "${docker_container.ovpn_server.ip_address}"
    router_lan_if_name   = "tun0"
    router_allow_wan_ssh = true
  }
}
