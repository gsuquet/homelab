# Ansible Role: os_hardening

[<- Back to Ansible Roles Overview](../index.md)

Documentation for the `os_hardening` Ansible role.

<!-- BEGIN_ANSIBLE_DOCS -->
### Tasks Overview

Tasks defined in `tasks/main.yml`:

- Install fail2ban
- Enable fail2ban
- Install ufw
- Configure ufw to deny all incoming connections by default
- Allow ssh from ip range
- Enable UFW
- Disable root SSH login
- Ensure SSH protocol 2 is used
- Disable password authentication for SSH
- Install automatic upgrades

### Variables & Defaults

*No default variables configured.*
<!-- END_ANSIBLE_DOCS -->
