terraform {
  required_providers {
    virtualbox = {
      source = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

# There are currently no configuration options for the provider itself.

resource "virtualbox_vm" "node" {
  count     = 1
  name      = format("node-%02d", count.index + 1)
  image     = "https://app.vagrantup.com/ubuntu/boxes/focal64/versions/20211026.0.0/providers/virtualbox.box"
  # image     = "/mnt/data/temp/2del/download/virtualbox.box"
  cpus      = 2
  memory    = "1.0 gib"
  # user_data = file("${path.module}/user_data")

  network_adapter {
    type           = "hostonly"
    host_interface = "vboxnet0"
  }

  # network_adapter {
  #   type           = "bridged"
  #   host_interface = "enp0s31f6"
  # }

  connection {
    type     = "ssh"
    user     = "vagrant"
    # password = var.root_password
    # host     = self.public_ip
    host     = "${element(virtualbox_vm.node.*.network_adapter.0.ipv4_address, 0)}"
    private_key = file("~/.vagrant.d/insecure_private_key")
  }

  provisioner "remote-exec" {
    inline = [
      "ip addr",
      "sudo touch /root/aaabbbccc"
    ]
  }

  provisioner "local-exec" {
    # when    = destroy
    command = "echo 'there you go'"
  }
}

output "IPAddr" {
  value = element(virtualbox_vm.node.*.network_adapter.0.ipv4_address, 1)
}

# output "IPAddr_2" {
#   value = element(virtualbox_vm.node.*.network_adapter.0.ipv4_address, 2)
# }

