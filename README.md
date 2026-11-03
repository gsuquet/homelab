# Homelab

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](renovate.json)

The code of a personal Kubernetes platform, at <https://github.com/gsuquet/homelab>.

## Project description

With this repository, you can create a Kubernetes cluster from Terraform modules, and then let Argo CD deploy its workloads from Git. Each change gets its first test on `kind-local`, a Kind cluster on a computer. One command creates the cluster, and one command removes it.

The repository has these parts:

| Folder | Content |
| --- | --- |
| `modules/` | Terraform child modules: `cluster-kind`, `bootstrap-gateway-api`, `bootstrap-cilium`, `bootstrap-cert-manager` and `bootstrap-argocd`. |
| `instances/` | One Terraform root module for each instance. The instance `kind-local` uses `cluster-kind`, `bootstrap-gateway-api`, `bootstrap-cilium` and `bootstrap-argocd`. |
| `gitops/` | The Helm sources of the components, and the rendered manifests of each cluster. Argo CD applies the rendered manifests. |
| `policy/`, `schemas/` | The Conftest policies and the JSON schemas that check each change. |
| `.mise/` | The pinned tools and the `mise run` tasks. |
| `docs/` | The documentation. |

`ansible/` and `kubernetes/` are legacy folders. New work does not use them. Refer to [Repository structure](docs/reference/repository-structure.md#legacy-folders).

## Who this project is for

This project is for engineers who want to read, run or copy a GitOps platform that starts on a local cluster. It is a personal platform, not a product. It has no releases and no support contract.

## Project dependencies

Before you use the repository, make sure that you have:

- a Mac or a Linux computer with a minimum of 8 GiB of memory;
- [mise](https://mise.jdx.dev/), activated in your shell. mise installs the other tools at the versions that `.mise/config.toml` pins;
- the `docker` command and a Docker runtime, for example [Colima](https://github.com/abiosoft/colima);
- `kubectl`;
- Git.

## Instructions for using the repository

To start, run the tutorial [Run your first local cluster](docs/tutorials/run-your-first-local-cluster.md). It starts `kind-local`, shows Argo CD as it syncs the cluster from Git, and removes the cluster.

### Install the tools

1. Clone the repository, and go to its root:

   ```bash
   git clone https://github.com/gsuquet/homelab.git
   cd homelab
   ```

2. Install the pinned tools:

   ```bash
   mise install
   ```

### Run the local cluster

1. Create the cluster and install Argo CD:

   ```bash
   mise run instance:up kind-local
   ```

2. Remove the cluster when you do not need it:

   ```bash
   mise run instance:down kind-local
   ```

The arguments, the steps and the exit status of these tasks are in [Instance tasks](docs/reference/instance-tasks.md).

### Troubleshoot the local cluster

| Problem | Solution |
| --- | --- |
| `instance:up` fails with `TLS handshake timeout`, or it tells that the Docker VM has not enough memory. | [Resize the Colima VM](docs/how-to/resize-the-colima-vm.md) |
| Image pulls fail with `x509: certificate signed by unknown authority` behind a company proxy. | [Use Kind behind a TLS-inspecting proxy](docs/how-to/use-kind-behind-a-tls-inspecting-proxy.md) |
| A task stops because a command is missing. | [Install the tools](docs/how-to/install-the-tools.md) |

## Contributing guidelines

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you change the repository. It gives the tasks, the checks and the review flow of a change.

## More documentation

The [documentation index](docs/index.md) lists all the pages, by type:

- [Tutorials](docs/index.md#tutorials): learn the platform step by step.
- [How-to guides](docs/index.md#how-to-guides): do one specific task.
- [Reference](docs/index.md#reference): find a fact, for example a task, a file or a rule.
- [Explanation](docs/index.md#explanation): understand why the platform has its form.

## How to get help

- To ask a question or report a bug, open an issue at <https://github.com/gsuquet/homelab/issues>. Refer to the [support policy](https://github.com/gsuquet/.github/blob/main/SUPPORT.md).
- To report a vulnerability, do not open an issue. Obey the [security policy](https://github.com/gsuquet/.github/blob/main/SECURITY.md).
- All the people in the project obey the [code of conduct](https://github.com/gsuquet/.github/blob/main/CODE_OF_CONDUCT.md).

## Terms of use

The repository has the [MIT license](LICENSE), except the upstream copies, which keep their own license.
