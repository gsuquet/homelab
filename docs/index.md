# HomeLab

A personal infrastructure learning environment and configuration archive for Terraform modules, Ansible roles, Helm chart values, and Kubernetes GitOps patterns.

While the primary active deployment target is a single-node [K3s](https://k3s.io/) Raspberry Pi (`olympus.local`) hosting smart home services (Home Assistant, Mosquitto, Zigbee2MQTT, ActualBudget), the repo is modularly structured to support local environments (Kind) and future cloud provider targets.

## Quick Navigation

| Section | Purpose |
| ------- | ------- |
| [Tutorials](#tutorials) | Step-by-step guides for setting up the homelab from scratch |
| [How-to Guides](#how-to-guides) | Recipes for specific operational tasks |
| [Reference](#reference) | Technical specifications and lookup tables |
| [Explanation](#explanation) | Conceptual background and architecture decisions |

---

## Tutorials

Learning-oriented guides that walk you through end-to-end tasks. Start here if you are new.

| Guide | Description |
| ----- | ----------- |
| [Getting Started](tutorials/01-getting-started.md) | Provision `olympus.local` from scratch — Ansible, K3S, ArgoCD |
| [Add Your First Application](tutorials/02-add-first-application.md) | Deploy a new self-hosted app to the cluster via GitOps |

---

## How-to Guides

Task-oriented recipes that solve a specific problem. Assumes familiarity with the platform.

| Guide | Description |
| ----- | ----------- |
| [Provision a New Server](how-to/provision-new-server.md) | Add a new node or reprovision an existing one |
| [Upgrade K3S](how-to/upgrade-k3s.md) | Upgrade the Kubernetes distribution to a new version |
| [Update ArgoCD](how-to/update-argocd.md) | Bump the ArgoCD Helm chart version |
| [Manage Secrets](how-to/manage-secrets.md) | Create and commit encrypted secrets with Sealed Secrets |
| [Add a Zigbee Device](how-to/add-zigbee-device.md) | Pair a new Zigbee device and expose it to Home Assistant |
| [Render Manifests](how-to/render-manifests.md) | Re-render Helm charts to plain YAML after a config change |
| [Configure Cloudflare](how-to/configure-cloudflare.md) | Set up the Cloudflare tunnel for external access |

---

## Reference

Information-oriented documentation for looking up technical details.

| Document | Description |
| -------- | ----------- |
| [Repository Structure](reference/repository-structure.md) | Annotated directory tree of the full repository |
| [Ansible Roles](reference/ansible-roles/index.md) | All roles with purpose, key variables, and usage |
| [Terraform Modules](reference/terraform-modules/index.md) | Infrastructure modules for cluster & local dev |
| [Applications](reference/applications.md) | Deployed apps with versions, ports, and storage |
| [Mise Tasks](reference/mise-tasks.md) | All `mise run` tasks with descriptions and usage |
| [Tools](reference/tools.md) | All project tools with versions and install methods |

---

## Explanation

Understanding-oriented documents that explain the *why* behind architectural decisions.

| Document | Description |
| -------- | ----------- |
| [Architecture](explanation/architecture.md) | Overall system design and component relationships |
| [GitOps with ArgoCD](explanation/gitops-with-argocd.md) | How ArgoCD manages the cluster from Git |
| [Rendered Manifests Pattern](explanation/rendered-manifests-pattern.md) | Why Helm charts are pre-rendered and committed |
| [Secret Management](explanation/secret-management.md) | How Sealed Secrets enables encrypted GitOps secrets |
| [Smart Home Stack](explanation/smart-home-stack.md) | How Zigbee2MQTT, Mosquitto, and Home Assistant work together |
| [Automated Updates](explanation/automated-updates.md) | How Renovate keeps dependencies current |
