locals {
  playbook_name = "/tmp/vagrant-provision/${basename(var.playbook)}"
}

resource "null_resource" "ansible-local-provision" {
  connection {
    type        = "ssh"
    host        = var.connection.host
    user        = var.connection.user
    private_key = var.connection.private_key
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /tmp/vagrant-provision/"]
  }

  provisioner "file" {
    source = var.playbook
    destination = local.playbook_name
  }

  provisioner "file" {
    content = "${yamlencode(var.extra_vars)}"
    destination = "/tmp/vagrant-provision/vars_file.yml"
  }

  provisioner "remote-exec" {
    inline = [
      join("", [
        "/home/${var.connection.user}/.cache/venv/ansible/bin/ansible-playbook ",
        " -i localhost, -c local --extra-vars @/tmp/vagrant-provision/vars_file.yml ",
        "${local.playbook_name}"
      ])
    ]
  }

  provisioner "remote-exec" {
    inline = ["rm -rf /tmp/vagrant-provision/"]
  }
}