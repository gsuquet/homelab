# Reference: Repository Structure

Annotated directory tree of the full repository.

```ascii
homelab/
├── ansible/                          # Infrastructure provisioning
│   ├── ansible.cfg                   # Ansible configuration (inventory path, roles path)
│   ├── inventory/
│   │   ├── hosts.yml                 # Host definitions (olympus.local → k3s_server)
│   │   └── group_vars/
│   │       ├── all.yml               # Variables for all hosts (k3s_version, timezone, user)
│   │       └── k3s_server.yml        # Variables for K3S server nodes (API endpoint, cluster config)
│   ├── playbooks/
│   │   ├── install.yml               # Full cluster provisioning (OS → K3S → ArgoCD)
│   │   ├── upgrade.yml               # K3S version upgrade (rolling, serial: 1)
│   │   └── reboot.yml                # Reboot all hosts
│   └── roles/
│       ├── k3s_common/               # Kernel networking, firewall rules, IP forwarding
│       ├── k3s_server/               # K3S control-plane install and kubeconfig setup
│       ├── k3s_agent/                # K3S worker node install and cluster join
│       ├── k3s_upgrade/              # In-place K3S version upgrade
│       ├── k8s_argocd/               # Apply ArgoCD manifests and bootstrap application
│       ├── os_hardening/             # UFW, fail2ban, SSH hardening (Ubuntu/Debian)
│       ├── os_raspberrypi/           # Raspberry Pi cgroup enablement (multi-distro)
│       └── raspberrypi/              # Additional Raspberry Pi configuration
│
├── kubernetes/
│   ├── bootstrap/
│   │   └── argo-cd/                  # ArgoCD self-managed installation
│   │       ├── sources/
│   │       │   ├── chart.yaml        # Helm chart dependency (argo-cd 9.5.2)
│   │       │   └── values.yaml       # ArgoCD Helm values
│   │       ├── manifests/
│   │       │   ├── install.yaml      # Full rendered output (do not edit directly)
│   │       │   └── *.yaml            # Split individual resource manifests
│   │       ├── bootstrap-application.yaml       # ArgoCD self-management Application
│   │       ├── applications-applicationset.yaml # Auto-discovers kubernetes/applications/*
│   │       ├── system-applicationset.yaml       # Auto-discovers kubernetes/system/*
│   │       ├── projects-application.yaml        # Manages ArgoCD Projects
│   │       └── kustomization.yaml
│   │
│   ├── projects/
│   │   ├── applications.yaml         # ArgoCD Project: user applications
│   │   └── system.yaml               # ArgoCD Project: system components
│   │
│   ├── applications/                 # User-facing self-hosted applications
│   │   ├── actualbudget/             # Personal finance (ActualBudget 25.12.0, port 5006)
│   │   ├── homeassistant/            # Home automation (HA 2026.7.4, port 8123)
│   │   ├── mosquitto/                # MQTT broker (Mosquitto 2.0.22, port 8883)
│   │   └── zigbee2mqtt/              # Zigbee bridge (Z2M 2.7.0, port 8080)
│   │
│   └── system/                       # Platform-level infrastructure
│       ├── cloudflare/               # Cloudflare tunnel (cloudflared 2025.11.1)
│       └── sealed-secrets/           # Secret encryption controller (v0.30.0)
│
├── .mise/
│   ├── config.toml                   # Tool versions (Helm, Python, pre-commit, yq, etc.)
│   └── tasks/
│       ├── changelog/                # Changelog generation task
│       ├── doc/                      # Documentation generation and check tasks
│       ├── manifests/                # Manifest render and check tasks
│       ├── pr/                       # PR creation helper script
│       └── tf/                       # Terraform docs tasks
│
├── scripts/                          # Custom utility scripts (generate-ansible-docs.sh)
│
├── terraform/                        # Infrastructure as Code
│   └── modules/
│       └── kind-cluster/             # Kind cluster dev module
│
├── docs/                             # Project documentation (Diátaxis structure)
│   ├── index.md                      # Landing page and navigation
│   ├── tutorials/                    # Learning-oriented guides
│   ├── how-to/                       # Task-oriented recipes
│   ├── reference/                    # Technical lookup tables (ansible-roles/, terraform-modules/)
│   └── explanation/                  # Conceptual background
│
├── AGENTS.md                         # Guidelines for AI coding agents
├── CHANGELOG.md                      # Automated commit changelog
├── CONTRIBUTING.md                   # Contributor workflow and standards
├── SECURITY.md                       # Security vulnerability disclosure policy
├── README.md                         # Good Docs Project landing page
├── .pre-commit-config.yaml           # Git hooks (YAML lint, secret scan, manifest render, doc gen)
├── .yamllint.yaml                    # YAML linting rules
└── renovate.json                     # Automated dependency update configuration
```

---

## Key File Descriptions

| File | Purpose |
| ---- | ------- |
| `ansible/inventory/hosts.yml` | Single source of truth for which hosts exist and what groups they belong to |
| `ansible/inventory/group_vars/all.yml` | `k3s_version` is the authoritative K3S version for the cluster |
| `kubernetes/bootstrap/argo-cd/sources/chart.yaml` | Bumping `version` here triggers an ArgoCD upgrade after re-rendering |
| `kubernetes/bootstrap/argo-cd/bootstrap-application.yaml` | The first ArgoCD Application applied manually; it makes ArgoCD manage itself |
| `kubernetes/bootstrap/argo-cd/applications-applicationset.yaml` | Any new directory under `kubernetes/applications/` is automatically deployed |
| `.mise/config.toml` | Pin tool versions here; `mise install` installs them all |
| `renovate.json` | Defines which packages Renovate scans and auto-merge rules |
| `.pre-commit-config.yaml` | The `render-manifests` hook here ensures manifests are always in sync on commit |
