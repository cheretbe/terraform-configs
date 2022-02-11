terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

variable "yc_token" {}
variable "yc_cloud_id" {}
variable "yc_folder_id" {}
variable "yc_zone" {}
variable "public_key" {}
variable "private_key" {}
variable "cf_api_email" {}
variable "cf_api_key" {}
variable "cf_zone_id" {}
variable "cf_dns_record_id" {}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

resource "yandex_vpc_network" "terraform_network" {
  name = "terraform_network"
}

resource "yandex_vpc_subnet" "subnet_1" {
  name           = "subnet_1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.terraform_network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_compute_instance" "vpn-server" {
  name = "vpn-server"
  # https://cloud.yandex.ru/docs/compute/concepts/performance-levels
  platform_id = "standard-v3"

  resources {
    cores  = 2
    # memory = 1
    memory = 2
    # core_fraction = 50
    core_fraction = 100
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      # https://cloud.yandex.ru/marketplace/products/yc/ubuntu-20-04-lts
      image_id = "fd8ba0ukgkn46r0qr1gi"
      size = 5
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet_1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key)}"
  }
}

output "external_ip_address" {
  value = yandex_compute_instance.vpn-server.network_interface[0].nat_ip_address
}

locals {
  server_ssh_connection = {
    host        = "${yandex_compute_instance.vpn-server.network_interface[0].nat_ip_address}"
    user        = "ubuntu"
    private_key = "${file(var.private_key)}"
  }
}

module "ovpn_server_ansible" {
  source = "../modules/ansible-controller"

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
    inline = ["mkdir -p /home/${local.server_ssh_connection.user}/ansible-data"]
  }

  provisioner "file" {
    source = "${path.module}/local/ca.crt"
    destination = "/home/${local.server_ssh_connection.user}/ansible-data/ca.crt"
  }

  provisioner "file" {
    source = "${path.module}/local/vpn-ru.chere.one.crt"
    destination = "/home/${local.server_ssh_connection.user}/ansible-data/vpn-ru.chere.one.crt"
  }

  provisioner "file" {
    source = "${path.module}/local/vpn-ru.chere.one.key"
    destination = "/home/${local.server_ssh_connection.user}/ansible-data/vpn-ru.chere.one.key"
  }

  provisioner "file" {
    source = "${path.module}/local/ta.key"
    destination = "/home/${local.server_ssh_connection.user}/ansible-data/ta.key"
  }
}

module "ovpn_server_provision" {
  source = "../modules/ansible-local-provision"

  depends_on=[module.ovpn_server_ansible]
  connection = local.server_ssh_connection
  playbook = "${path.module}/provision/server_provision.yml"
  extra_vars = {
    ovpn_server_ca_cert  = "/home/${local.server_ssh_connection.user}/ansible-data/ca.crt"
    ovpn_server_cert     = "/home/${local.server_ssh_connection.user}/ansible-data/vpn-ru.chere.one.crt"
    ovpn_server_key      = "/home/${local.server_ssh_connection.user}/ansible-data/vpn-ru.chere.one.key"
    ovpn_server_ta_key   = "/home/${local.server_ssh_connection.user}/ansible-data/ta.key"
    ovpn_server_dns_name = "vpn-ru.chere.one"
    router_wan_if_mac_addr = "${yandex_compute_instance.vpn-server.network_interface[0].mac_address}"
    router_lan_if_name   = "tun0"
    router_allow_wan_ssh = true
    router_custom_ports = [
      {
        protocol= "udp"
        port = 1194
        comment = "Allow VPN"
      }
    ],
    cf_api_email = "${var.cf_api_email}",
    cf_api_key = "${var.cf_api_key}",
    cf_zone_id = "${var.cf_zone_id}",
    cf_dns_record_id = "${var.cf_dns_record_id}",
    cf_dns_record_content = "${yandex_compute_instance.vpn-server.network_interface[0].nat_ip_address}"
  }
}
