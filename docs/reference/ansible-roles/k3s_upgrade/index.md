# Ansible Role: k3s_upgrade

[<- Back to Ansible Roles Overview](../index.md)

Documentation for the `k3s_upgrade` Ansible role.

<!-- BEGIN_ANSIBLE_DOCS -->
### Tasks Overview

Tasks defined in `tasks/main.yml`:

- Get k3s installed version
- Set k3s installed version
- Update node if installed version is older than requested
- Find K3s service files
- Save current K3s service
- Install new K3s version
- Restore K3s service
- Clean up temporary K3s service backups
- Restart K3s service [server]
- Restart K3s service [agent]

### Variables & Defaults

*No default variables configured.*
<!-- END_ANSIBLE_DOCS -->
