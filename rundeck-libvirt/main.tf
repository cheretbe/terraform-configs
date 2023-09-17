terraform {
  required_providers {
    libvirt = {
      # https://registry.terraform.io/providers/dmacvicar/libvirt/latest
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
  }
  backend "local" {
    # The path is configured in 'backend.tfvars' and initialized like that:
    # terraform init -backend-config=backend.tfvars
  }
}

variable "libvirt_ssh_user_name" {
}
variable "libvirt_host" {
}
variable "vm_users" {
}
variable "libvirt_bridge_name" {
}
variable "libvirt_pool_name" {
  default = "hdd1"
}
variable "libvirt_memory" {
  default = "1024"
}
variable "libvirt_vcpu" {
  default = 1
}
variable "libvirt_image_url" {
  default = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}
variable "libvirt_vm_hostname" {
  default     = "rundeck"
}
variable "libvirt_vm_mac_address" {
  # https://dnschecker.org/mac-address-generator.php
  default     = "30:EA:2E:DC:F0:30"
}
variable "libvirt_ssh_private_key" {
  default = "~/.ssh/id_ed25519"
}

provider "libvirt" {
  uri = "qemu+ssh://${var.libvirt_ssh_user_name}@${var.libvirt_host}/system?keyfile=${var.libvirt_ssh_private_key}"
}

# If image creation fails with "Could not open '/mnt/hdd1/vm/rundeck': Permission denied" error:
# Set security_driver = "none" in /etc/libvirt/qemu.conf and restart service:
# systemctl restart libvirtd
# https://github.com/dmacvicar/terraform-provider-libvirt/issues/978#issuecomment-1276244924

# resource "libvirt_volume" "rundeck_qcow2" {
#   name = "rundeck.qcow2"
#   pool = var.libvirt_pool_name
#   source = var.libvirt_image_url
#   format = "qcow2"
#   # 15 GiB
#   size = 16106127360
# }

# Use this when debugging to speed up volume creation
resource "libvirt_volume" "rundeck_qcow2" {
  name = "rundeck.qcow2"
  pool = var.libvirt_pool_name
  base_volume_pool = "images"
  base_volume_name = "jammy-server-cloudimg-amd64.img"
  # 15 GiB
  size = 16106127360
}

# locals {
#   debug_cloud_init = templatefile("${path.module}/cloud_init.yml.tftpl", {vm_users = var.vm_users})
# }

resource "libvirt_cloudinit_disk" "rundeck_cloudinit" {
  name           = "rundeck_cloudinit.iso"
  user_data      = templatefile("${path.module}/cloud_init.yml.tftpl", {vm_users = var.vm_users})
  network_config = file("${path.module}/network_config.yml")
  pool           = var.libvirt_pool_name
}

resource "libvirt_domain" "rundeck" {
  name   = var.libvirt_vm_hostname
  memory = var.libvirt_memory
  vcpu   = var.libvirt_vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.rundeck_cloudinit.id

  network_interface {
    bridge         = var.libvirt_bridge_name
    mac            = var.libvirt_vm_mac_address
    hostname       = var.libvirt_vm_hostname
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.rundeck_qcow2.id
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Hello World'"
    ]

    connection {
      type                = "ssh"
      user                = var.libvirt_ssh_user_name
      host                = libvirt_domain.rundeck.network_interface[0].addresses[0]
      # [!] Don't set 'private_key' option otherwise 'agent' option won't work
      agent               = true
      timeout             = "2m"
    }
  }
}

output "rundeck_server_ip" {
  value = "${libvirt_domain.rundeck.network_interface[0].addresses[0]}"
}
