# Ansible Role: k3s_common

[<- Back to Ansible Roles Overview](../index.md)

Documentation for the `k3s_common` Ansible role.

<!-- BEGIN_ANSIBLE_DOCS -->
### Tasks Overview

Tasks defined in `tasks/main.yml`:

- Enforce minimum Ansible version
- Install Dependent Ubuntu Packages
- Enable IPv4 forwarding
- Enable IPv6 forwarding
- Populate service facts
- Allow UFW Exceptions
- Get ufw status
- If ufw enabled, open api port
- If ufw enabled, open etcd ports
- If ufw enabled, allow default CIDRs
- Allow Firewalld Exceptions
- If firewalld enabled, open api port
- If firewalld enabled, open etcd ports
- If firewalld enabled, open inter-node ports
- If firewalld enabled, allow node CIDRs
- If firewalld enabled, allow default CIDRs
- Add br_netfilter to /etc/modules-load.d/
- Load br_netfilter
- Set bridge-nf-call-iptables (just to be sure)
- Check for Apparmor existence
- Check if Apparmor is enabled
- Install Apparmor Parser [Suse]
- Install Apparmor Parser [Debian]
- Gather the package facts
- If old iptables found, change to iptables-legacy
- Iptables version on node
- Flush iptables before changing to iptables-legacy
- Changing to iptables-legacy
- Changing to ip6tables-legacy
- If iptables v1.8.0-1.8.4, warn user  # noqa ignore-errors
- Add /usr/local/bin to sudo secure_path
- Setup alternative K3s directory
- Make rancher directory
- Create symlink
- Setup extra manifests
- Make manifests directory
- Copy manifests
- Setup optional private registry configuration
- Make k3s config directory
- Copy config values

### Variables & Defaults

`vars/main.yml`:

```yaml
---
cluster_cidr: "{{ (server_config_yaml | from_yaml)['cluster-cidr'] | default('10.42.0.0/16') }}"
service_cidr: "{{ (server_config_yaml | from_yaml)['service-cidr'] | default('10.43.0.0/16') }}"
```
<!-- END_ANSIBLE_DOCS -->
