# Ansible Role: os_raspberrypi

[<- Back to Ansible Roles Overview](../index.md)

Documentation for the `os_raspberrypi` Ansible role.

<!-- BEGIN_ANSIBLE_DOCS -->
### Tasks Overview

Tasks defined in `tasks/main.yml`:

- Test for raspberry pi /proc/cpuinfo
- Test for raspberry pi /proc/device-tree/model
- Set raspberry_pi fact to true
- Set detected_distribution to ArchLinux (ARM64)
- Set detected_distribution to Debian
- Set detected_distribution to Raspbian
- Set detected_distribution to CentOS
- Set detected_distribution to Ubuntu
- Execute OS related tasks on the Raspberry Pi

### Variables & Defaults

*No default variables configured.*
<!-- END_ANSIBLE_DOCS -->
