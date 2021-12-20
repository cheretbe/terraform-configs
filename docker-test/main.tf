terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.15.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_network" "terraform_network" {
  name = "terraform_network"
  attachable = true
  driver = "bridge"
}

# Pulls the image
resource "docker_image" "ubuntu" {
  name = "geerlingguy/docker-ubuntu2004-ansible"
  keep_locally = true
}

resource "docker_container" "foo1" {
  image = docker_image.ubuntu.latest
  name  = "terraform-docker-test-1"
  restart = "on-failure"
  # publish_all_ports = true
  command = [ "/usr/lib/systemd/systemd" ]

  networks_advanced {
    name = "${docker_network.terraform_network.name}"
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

resource "docker_container" "foo2" {
  image = docker_image.ubuntu.latest
  name  = "terraform-docker-test-2"
  restart = "on-failure"
  # publish_all_ports = true
  command = [ "/usr/lib/systemd/systemd" ]

  networks_advanced {
    name = "${docker_network.terraform_network.name}"
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

output "IP1" {
  value = "${docker_container.foo1.ip_address}"
}

output "IP2" {
  value = "${docker_container.foo2.ip_address}"
}

resource "null_resource" "provision" {
    provisioner "local-exec" {
      # command = "./provision/ssh_config.sh ${docker_container.foo1.ip_address}"
      command = "docker cp ./provision/ssh_config.sh ${docker_container.foo1.name}:/tmp/ && docker exec ${docker_container.foo1.name} bash /tmp/ssh_config.sh"
    }

    connection {
      type     = "ssh"
      user     = "vagrant"
      # password = var.root_password
      # host     = self.public_ip
      host     = "${docker_container.foo1.ip_address}"
      private_key = file("~/.vagrant.d/insecure_private_key")
    }
    provisioner "file" {
      source      = "provision/requirements.txt"
      destination = "/home/vagrant/requirements.txt"
    }
    provisioner "remote-exec" {
      inline = ["/usr/bin/curl -s https://raw.githubusercontent.com/cheretbe/bootstrap/master/setup_venv.py?flush_cache=True | /usr/bin/python3 - ansible --batch-mode --requirement /home/vagrant/requirements.txt"]
    }
    provisioner "file" {
      source      = "provision/ansible_test.yml"
      destination = "/home/vagrant/ansible_test.yml"
    }
    provisioner "remote-exec" {
      inline = ["/home/vagrant/.cache/venv/ansible/bin/ansible-playbook -i localhost, -c local /home/vagrant/ansible_test.yml"]
    }
}
