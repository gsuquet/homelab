# HomeLab

A personal infrastructure learning environment and configuration archive for Terraform modules, Ansible roles, Helm chart values, and Kubernetes GitOps patterns.

While the primary active deployment target is a single-node [K3s](https://k3s.io/) Raspberry Pi (`olympus.local`) hosting smart home services (Home Assistant, Mosquitto, Zigbee2MQTT, ActualBudget), the repo is modularly structured to support local environments (Kind) and future cloud provider targets.

## Quick Navigation

| Section | Purpose |
| ------- | ------- |
| [Tutorials](#tutorials) | Step-by-step guides for setting up the homelab from scratch |
| [How-to Guides](#how-to-guides) | Recipes for specific operational tasks |
| [Reference](#reference) | Technical specifications and lookup tables |
| [Explanation](#explanation) | Conceptual background: how the system works, and why |

---

## Tutorials

Learning-oriented guides that walk you through end-to-end tasks. Start here if you are new.

| Guide | Description |
| ----- | ----------- |

---

## How-to Guides

Task-oriented recipes that solve a specific problem. Assumes familiarity with the platform.

| Guide | Description |
| ----- | ----------- |
| [Render Manifests](how-to/render-manifests.md) | Re-render Helm charts to plain YAML after a config change |
| [Add a GitOps Component](how-to/add-gitops-component.md) | Deploy an infrastructure component or an app to a cluster with Argo CD |
| [Open the Argo CD UI](how-to/open-argocd-ui.md) | Log in to Argo CD on an instance with a port-forward |
| [Configure Cloudflare](how-to/configure-cloudflare.md) | Set up the Cloudflare tunnel for external access |
| [Use Kind behind a TLS-inspecting proxy](how-to/use-kind-behind-a-tls-proxy.md) | Make the Colima VM and the Kind nodes trust a company proxy CA |
| [Resize the Colima VM](how-to/resize-the-colima-vm.md) | Fix a `TLS handshake timeout` during the apply of a Kind instance |
| [Rename the Repository](how-to/rename-the-repository.md) | Rename `gsuquet/homelab` to `gsuquet/infra` without a loss on `olympus` |
| [Import Provider Resources](how-to/import-provider-resources.md) | Bring the resources of a provider account under Terraform |

---

## Reference

Information-oriented documentation for looking up technical details.

| Document | Description |
| -------- | ----------- |
| [Repository Structure](reference/repository-structure.md) | Annotated directory tree of the full repository |
| [Terraform Modules](reference/terraform-modules/index.md) | Infrastructure modules for cluster & local dev |
| [Mise Tasks](reference/mise-tasks.md) | All `mise run` tasks with descriptions and usage |
| [Tools](reference/tools.md) | All project tools with versions and install methods |
| [Writing Rules](reference/writing-rules.md) | The Diátaxis sections, ASD-STE100 and the Vale checks |
| [Policies](reference/policies.md) | The Conftest policies and what each one checks |
| [Schemas](reference/schemas.md) | The JSON Schemas of `module.yaml`, `instance.yaml` and `cluster.yaml` |
| [How We Work](reference/how-we-work.md) | The rules for issues, PRs, labels, the review, commits and the merge |
| [Labels and Annotations](reference/labels-and-annotations.md) | The Kubernetes and cloud label keys, and their checks |
| [Provider Accounts](reference/provider-accounts.md) | The scope rule, `accounts/`, state, credentials, budgets and naming |

---

## Explanation

Understanding-oriented documents that explain how the system works, and why. Each page also holds the decisions and their reasons.

| Document | Description |
| -------- | ----------- |
| [GitOps with ArgoCD](explanation/gitops-with-argocd.md) | How ArgoCD manages the cluster from Git |
| [Rendered Manifests Pattern](explanation/rendered-manifests-pattern.md) | Why Helm charts are pre-rendered and committed |
| [Automated Updates](explanation/automated-updates.md) | How Renovate keeps dependencies current |
| [How We Work](explanation/how-we-work.md) | The doc-first workflow, the review and the merge, and why |
| [Repository Structure](explanation/repository-structure.md) | Why the tree, the layouts and the naming rules have their form |
| [Labels and Annotations](explanation/labels-and-annotations.md) | Why the key prefix, the sub-groups and the checks have their form |
| [Repository Scope](explanation/repository-scope.md) | What belongs in the repository, the provider accounts and the name `infra` |

---

## Archive

Pages that are not maintained. Refer to [Archive](archive/README.md).
