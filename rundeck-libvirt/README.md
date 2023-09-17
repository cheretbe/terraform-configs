
`backend.tfvars` example:
```hcl
path = "/home/user/terraform-states/rundeck-libvirt-srv3/terraform.tfstate"
```

`terraform.tfvars` example:
```hcl
libvirt_ssh_user_name = "user"
libvirt_host = "host.domain.tld"
libvirt_pool_name = "hdd3"
libvirt_bridge_name = "enp2s0-br"

# mkpasswd -m sha512crypt
vm_users = {
  "user": {
    "password": "$6$0000000000000000000/00",
    "ssh_key": "ssh-ed25519 00000000000000000000000000000 user",
  },
  "ansible": {
    "password": null,
    "ssh_key": "ssh-ed25519 00000000000000000000000000000 ansible"
  }
}
```
