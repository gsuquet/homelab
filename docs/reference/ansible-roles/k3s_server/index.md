# Ansible Role: k3s_server

[<- Back to Ansible Roles Overview](../index.md)

Documentation for the `k3s_server` Ansible role.

<!-- BEGIN_ANSIBLE_DOCS -->
### Tasks Overview

Tasks defined in `tasks/main.yml`:

- Get k3s installed version
- Set k3s installed version
- Download k3s install script and binary if needed
- Download K3s install script
- Download K3s binary
- Add K3s autocomplete to user bashrc
- Setup optional config file
- Make config directory
- Copy config values
- Init first server node
- Copy K3s service file [Mono]
- Copy K3s service file [Multi]
- Add service environment variables
- Delete any existing token from the environment if different from the new one
- Add token as an environment variable
- Restart K3s service
- Enable and check K3s service
- Pause to allow first server startup
- Check whether kubectl is installed on control node
- Copy k3s.yaml to second file
- Apply K3S kubeconfig to control node
- Copy kubeconfig to control node
- Change server address in kubeconfig on control node
- Fix certificate hostname in control node kubeconfig if needed
- Setup kubeconfig context on control node - {{ cluster_context }}
- Merge with any existing kubeconfig on control node
- Get the token if randomly generated
- Wait for token
- Read node-token from master
- Store Master node-token
- Start other server if any and verify status
- Get the token from the first server
- Delete any existing token from the environment if different from the new one
- Add the token for joining the cluster to the environment
- Copy K3s service file [Multi]
- Copy K3s service file [External DB]
- Restart K3s service
- Enable and check K3s service
- Verify that all server nodes joined
- Setup kubectl for user
- Create directory .kube
- Copy config file to user home directory
- Fix certificate hostname in kubeconfig if needed
- Configure default KUBECONFIG for user
- Configure kubectl autocomplete

### Variables & Defaults

*No default variables configured.*
<!-- END_ANSIBLE_DOCS -->
