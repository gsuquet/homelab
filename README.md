# HomeLab

> A personal infrastructure sandbox, configuration archive, and learning environment for Infrastructure as Code, Kubernetes GitOps, Ansible, and Terraform.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](renovate.json)

---

## Overview

This repository serves as a **personal learning sandbox and configuration archive**. It acts as a single source of truth for modular Terraform configurations, Helm chart values, Ansible roles, and Kubernetes manifest patterns.

While the codebase currently deploys a live smart home and personal services stack to a Raspberry Pi (`olympus.local`), the architecture is modular and provider-agnostic — designed to support local development environments (e.g. `Kind`), cloud providers, and multi-node clusters.

### Key Focus Areas

- **Infrastructure as Code & Modules**: Modular Terraform (`terraform/modules/`) and Ansible roles (`ansible/roles/`) designed for reuse and learning.
- **GitOps & Rendered Manifests**: ArgoCD-driven deployment using local Helm rendering for complete transparency and declarative auditability.
- **Multi-Environment Ready**: Targets local dev clusters (`Kind`), bare-metal nodes (Raspberry Pi / K3s), and extensible for cloud targets.
- **Security & Secret Hygiene**: Sealed Secrets for Git-committed secrets, UFW firewall hardening, and Zero-Trust Cloudflare Tunnels.
- **Automated Maintenance**: Renovate bot for dependency management and pre-commit hooks for linting and doc generation.

---

## Quickstart

### Prerequisites

- Operating System: Linux (Debian/Ubuntu/Raspbian) or macOS (for CLI management)
- Managed via [Mise](https://mise.jdx.dev/) tool manager

### Setup Instructions

1. **Clone Repository**:

   ```bash
   git clone https://github.com/gsuquet/homelab.git
   cd homelab
   ```

2. **Install Development Tools**:

   ```bash
   mise install
   ```

3. **Provision Node**:

   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/install.yml
   ```

4. **Verify Deployment**:

   ```bash
   kubectl get nodes
   kubectl get pods -n argocd
   ```

---

## Documentation

Full documentation is organized using the **Diátaxis framework** in the [`docs/`](docs/index.md) directory:

| Section | Description | Link |
|---------|-------------|------|
| **Tutorials** | Learning-oriented step-by-step guides for getting started | [Explore Tutorials](docs/index.md#tutorials) |
| **How-to Guides** | Operational task-oriented recipes (updating K3s, secrets, Zigbee) | [Explore How-to Guides](docs/index.md#how-to-guides) |
| **Reference** | Technical specifications, Ansible roles, tools, and apps | [Explore Reference](docs/index.md#reference) |
| **Explanation** | Architectural decisions, GitOps patterns, and design rationale | [Explore Explanations](docs/index.md#explanation) |

---

## Contributing

Contributions, feedback, and issue reports are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on code standards, commit formatting, and pull request workflows.

Please note that this project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

---

## Security

For security vulnerability reporting instructions, please see [SECURITY.md](SECURITY.md).

---

## License

This project is licensed under the MIT License - see [LICENSE.md](LICENSE.md) for details.
