```tf
module "ovpn_server_ansible" {
 source = "../modules/ansible-controller"

 depends_on=[module.ovpn_server_user]
 connection = local.server_ssh_connection
}
```
