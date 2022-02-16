locals {
  playbook_name = "/tmp/ansible-provision/${basename(var.playbook)}"
}

resource "null_resource" "ansible-provision" {
  connection {
    type        = "ssh"
    host        = var.controller_connection.host
    user        = var.controller_connection.user
    private_key = var.controller_connection.private_key
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/ansible-provision/"]
  }

  provisioner "file" {
    source = "${path.module}/controller_provision.yml"
    destination = "/tmp/ansible-provision/controller_provision.yml"
  }

  provisioner "remote-exec" {
    inline = [
      join("", [
        "ansible-playbook ",
        " -i localhost, -c local /tmp/ansible-provision/controller_provision.yml"
      ])
    ]
  }

  provisioner "file" {
    source = var.playbook
    destination = local.playbook_name
  }

  provisioner "file" {
    content = "${yamlencode(var.extra_vars)}"
    destination = "/tmp/ansible-provision/vars_file.yml"
  }

  provisioner "file" {
    content = var.server_connection.private_key
    destination = "/tmp/ansible-provision/ansible_ssh_key"
  }

  provisioner "remote-exec" {
    inline = ["chmod 600 /tmp/ansible-provision/ansible_ssh_key"]
  }

  provisioner "file" {
    content = yamlencode(
      {
        "all": {
          "vars": {
            "ansible_user": var.server_connection.user,
            "ansible_ssh_private_key_file": "/tmp/ansible-provision/ansible_ssh_key"
            "ansible_host_key_checking": false
          },
          "hosts": {
            "${var.server_connection.host}": {}
          }
        }
      }
    )
    destination = "/tmp/ansible-provision/inventory.yml"
  }

  provisioner "remote-exec" {
    inline = [
      join("", [
        "ansible-playbook ",
        "-i /tmp/ansible-provision/inventory.yml ",
        "--extra-vars @/tmp/ansible-provision/vars_file.yml ",
        "${local.playbook_name}"
      ])
    ]
  }

  provisioner "remote-exec" {
    inline = ["rm -rf /tmp/ansible-provision/"]
  }
}