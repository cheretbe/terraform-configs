resource "null_resource" "ansible-controller" {
  connection {
    type        = "ssh"
    host        = var.connection.host
    user        = var.connection.user
    private_key = var.connection.private_key
  }

  provisioner "file" {
    content = var.requirements
    destination = "/home/${var.connection.user}/requirements.txt"
  }

  provisioner "remote-exec" {
    inline = ["/usr/bin/curl -s https://raw.githubusercontent.com/cheretbe/bootstrap/master/setup_venv.py?flush_cache=True | /usr/bin/python3 - ansible --batch-mode --requirement /home/${var.connection.user}/requirements.txt"]
  }
}