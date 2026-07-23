# Ansible Role: k3s_agent

[<- Back to Ansible Roles Overview](../index.md)

Documentation for the `k3s_agent` Ansible role.

<!-- BEGIN_ANSIBLE_DOCS -->
### Tasks Overview

Tasks defined in `tasks/main.yml`:

- Get k3s installed version
- Set k3s installed version
- Download k3s install script and binary if needed
- Download K3s install script
- Download K3s binary
- Setup optional config file
- Make config directory
- Copy config values
- Get the token from the first server
- Delete any existing token from the environment if different from the new one
- Add the token for joining the cluster to the environment
- Copy K3s service file
- Enable and check K3s service

### Variables & Defaults

*No default variables configured.*
<!-- END_ANSIBLE_DOCS -->
