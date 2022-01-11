resource "null_resource" "vagrant-user" {
  provisioner "local-exec" {
    command = "docker cp ${path.module}/vagrant_user_ssh_config.sh ${var.container_name}:/tmp/ && docker exec ${var.container_name} bash /tmp/vagrant_user_ssh_config.sh"
  }
}
