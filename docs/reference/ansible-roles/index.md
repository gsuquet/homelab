# Ansible Roles Reference

Technical documentation for all Ansible roles used to provision and maintain `olympus.local`.

## Roles Index

| Role | Purpose | Main Playbook | Status |
|------|---------|---------------|--------|
| [`k3s_agent`](k3s_agent/index.md) | Join worker nodes to K3s cluster | `playbooks/install.yml` | Active |
| [`k3s_common`](k3s_common/index.md) | Shared OS prerequisites (kernel modules, networking, sysctl) | `playbooks/install.yml` | Active |
| [`k3s_server`](k3s_server/index.md) | Install K3s control plane server | `playbooks/install.yml` | Active |
| [`k3s_upgrade`](k3s_upgrade/index.md) | In-place rolling upgrades of K3s binaries | `playbooks/upgrade.yml` | Active |
| [`k8s_argocd`](k8s_argocd/index.md) | Bootstrap ArgoCD self-management Applications | `playbooks/install.yml` | Active |
| [`os_hardening`](os_hardening/index.md) | Security baseline (UFW, SSH hardening, Fail2ban) | `playbooks/install.yml` | Active |
| [`os_raspberrypi`](os_raspberrypi/index.md) | Raspberry Pi bootloader cgroups configuration | `playbooks/install.yml` | Active |
| `raspberrypi` | *Legacy role (superseded by `os_raspberrypi`)* | N/A | Obsolete |

---

## Role Details

For detailed task listings, default variables, and template configurations for each role, navigate to the individual role documentation linked above.
