# Homelab documentation

This repository holds the code of a personal platform. Terraform modules in `modules/` and instances in `instances/` create the clusters. Argo CD deploys the workloads from the sources in `gitops/`. Conftest policies, JSON schemas and Vale check each change. A cluster runs at home on Raspberry Pi nodes, and other instances run in the cloud. Each change gets its first test on `kind-local`, a Kind cluster on a computer.

If the repository is new to you, start with the tutorial [Run your first local cluster](tutorials/run-your-first-local-cluster.md). It starts `kind-local` with one command, shows Argo CD as it syncs the cluster from Git, and removes the cluster.

The pages have four types. Use the type that agrees with your need:

| Type | Use it to |
| --- | --- |
| [Tutorials](#tutorials) | Learn the platform step by step, to a visible result |
| [How-to guides](#how-to-guides) | Do one specific task |
| [Reference](#reference) | Find a fact: a task, a file, a rule or a setting |
| [Explanation](#explanation) | Understand why the platform has its form |

## Tutorials

| Page | Description |
| --- | --- |
| [Run your first local cluster](tutorials/run-your-first-local-cluster.md) | Start `kind-local`, see Argo CD repair a deleted resource, and remove the cluster |

## How-to guides

### Set up a computer

| Page | Description |
| --- | --- |
| [Install the tools](how-to/install-the-tools.md) | Install the pinned tools and the Git hooks |
| [Resize the Colima VM](how-to/resize-the-colima-vm.md) | Give the Colima VM more CPUs or memory for a Kind instance |
| [Use Kind behind a TLS-inspecting proxy](how-to/use-kind-behind-a-tls-proxy.md) | Make the Colima VM and the Kind nodes trust a company proxy CA |

### Operate the GitOps components

| Page | Description |
| --- | --- |
| [Add a GitOps component](how-to/add-a-gitops-component.md) | Deploy an infrastructure component or an application to a cluster with Argo CD |
| [Label a GitOps component](how-to/label-a-gitops-component.md) | Give a component and its Namespace the required labels |
| [Render manifests](how-to/render-manifests.md) | Update the rendered manifests after a change to a component |
| [Open the Argo CD UI](how-to/open-the-argo-cd-ui.md) | Open the Argo CD UI of an instance with a port-forward |
| [Force a sync](how-to/force-a-sync.md) | Make Argo CD apply a merged change at once |
| [Upgrade Argo CD](how-to/upgrade-argo-cd.md) | Upgrade Argo CD, or change its settings, on all the clusters |
| [Configure Cloudflare](how-to/configure-cloudflare.md) | Set up the Cloudflare tunnel for external access |

### Change the repository

| Page | Description |
| --- | --- |
| [Make a change](how-to/make-a-change.md) | Take a change from a plan to a merged pull request |
| [Change a Terraform provider version](how-to/change-a-terraform-provider-version.md) | Change the version of a provider and update the lock files |
| [Add or change a policy rule](how-to/add-or-change-a-policy-rule.md) | Add a Conftest rule to a policy, or change a rule |
| [Change a schema](how-to/change-a-schema.md) | Change a JSON schema and the fixtures that test it |
| [Add a word to the STE word list](how-to/add-a-word-to-the-ste-word-list.md) | Add a word that is not approved to the Vale check, with its replacement |
| [Sync the GitHub labels](how-to/sync-the-github-labels.md) | Make the GitHub labels equal to `.github/labels.yml` |

## Reference

### The platform

| Page | Description |
| --- | --- |
| [Instance tasks](reference/instance-tasks.md) | `instance:plan`, `instance:up` and `instance:down`: steps, variables and exit status |
| [Terraform modules](reference/terraform-modules/index.md) | The modules in `modules/`, with a page for each module |
| [GitOps layout](reference/gitops-layout.md) | The files in `gitops/`, how they render, and the settings of the Applications |
| [Labels and annotations](reference/labels-and-annotations.md) | The Kubernetes and cloud label keys, and their checks |

The module pages come from terraform-docs. `mise run doc:generate` updates them:

| Module | Page |
| --- | --- |
| `cluster-kind` | [cluster-kind](reference/terraform-modules/cluster-kind/index.md) |
| `bootstrap-gateway-api` | [bootstrap-gateway-api](reference/terraform-modules/bootstrap-gateway-api/index.md) |
| `bootstrap-cilium` | [bootstrap-cilium](reference/terraform-modules/bootstrap-cilium/index.md) |
| `bootstrap-cert-manager` | [bootstrap-cert-manager](reference/terraform-modules/bootstrap-cert-manager/index.md) |
| `bootstrap-argocd` | [bootstrap-argocd](reference/terraform-modules/bootstrap-argocd/index.md) |

### The repository and its tools

| Page | Description |
| --- | --- |
| [Repository structure](reference/repository-structure.md) | The folders, the root files and the naming rules |
| [Mise tasks](reference/mise-tasks.md) | The `mise run` tasks and what each one does |
| [Tools](reference/tools.md) | The pinned tools and their versions |
| [Policies](reference/policies.md) | The Conftest policies and what each one checks |
| [Schemas](reference/schemas.md) | The JSON schemas of `module.yaml`, `instance.yaml` and `cluster.yaml` |
| [Renovate settings](reference/renovate-settings.md) | The settings in `renovate.json` |
| [Work rules](reference/how-we-work.md) | The rules for the plans, the issues, the PRs, the review, the commits and the merge |
| [Writing rules](reference/writing-rules.md) | The page types, ASD-STE100 and the Vale checks |

### Page templates

Each new page starts from the template of its type:

| Template | Type |
| --- | --- |
| [Tutorial template](templates/tutorial.md) | Tutorial |
| [How-to template](templates/how-to.md) | How-to guide |
| [Reference template](templates/reference.md) | Reference |
| [Explanation template](templates/explanation.md) | Explanation |

## Explanation

| Page | Description |
| --- | --- |
| [Why the platform runs on a local cluster first](explanation/why-the-platform-runs-on-a-local-cluster-first.md) | Why each change gets its first test on `kind-local`, and what Kind does not show |
| [GitOps with Argo CD](explanation/gitops-with-argo-cd.md) | Why Git deploys the workloads, why `gitops/` has its shape, and why Argo CD manages itself |
| [Rendered manifests pattern](explanation/rendered-manifests-pattern.md) | Why the repository commits the output of Helm, and what this costs |
| [Why the label scheme has its form](explanation/why-the-label-scheme-has-its-form.md) | Why the key prefix, the sub-groups and the checks have their form |
| [Repository structure](explanation/repository-structure.md) | Why the tree, the layouts and the naming rules have their form |
| [Repository scope](explanation/repository-scope.md) | What belongs in the repository, and why its metadata uses the word `infra` |
| [How we work](explanation/how-we-work.md) | Why the work goes from a plan to the docs and then to the code |
| [Automated updates](explanation/automated-updates.md) | Why Renovate keeps the exact versions current, and how it groups the updates |

## Archive

Nobody maintains these pages, and Vale does not check them. The reasons are in [Archive](archive/README.md).

| Page | Description |
| --- | --- |
| [Chaos Citadel](archive/chaos-citadel.md) | A design for a cloud-native defense game |
| [Zero Trust and Chaos Lab](archive/zero-trust-chaos-lab.md) | The design for the Chaos Citadel test bed |
