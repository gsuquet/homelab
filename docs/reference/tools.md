# Tools

`.mise/config.toml` pins the command-line tools of the repository. `mise install` installs the versions of the `[tools]` section. `.mise/mise.lock` holds the lock data of each tool, because `[settings]` sets `lockfile = true`.

The `mise` policy makes sure that each version is exact and that the lock file stays on. Refer to [Policies](policies.md#mise). Renovate updates the versions. Refer to [Renovate settings](renovate-settings.md).

## Pinned tools

| Tool | Version | Purpose | Used by |
| --- | --- | --- | --- |
| `actionlint` | 1.7.12 | Linter for GitHub Actions workflows. | `lint:actions` |
| `cilium-cli` | 0.19.5 | The `cilium` command: status and tests of Cilium in a cluster. | No task |
| `cilium-hubble` | 1.19.4 | The `hubble` command: the network flows that Hubble records. | No task |
| `conftest` | 0.71.1 | Tests files against the Rego policies in `policy/`. | `lint:policy` |
| `git-cliff` | 2.8.0 | Changelog generator for Conventional Commits. | `changelog:generate` |
| `github-cli` | 2.103.0 | The `gh` command: issues, PRs, labels and projects on GitHub. | `labels:sync` |
| `gitleaks` | 8.30.1 | Scanner for secrets in Git. | No task. The `gitleaks` pre-commit hook uses its hook repository at `v8.30.1`. |
| `helm` | 4.3.1 | Renders the Helm charts in the `sources/` folders. | `manifests:render` |
| `kind` | 0.33.0 | Kubernetes clusters in Docker containers. | `instance:up`, to export the kubeconfig |
| `kubeconform` | 0.8.0 | Validates Kubernetes manifests against the Kubernetes schemas. | `manifests:validate` |
| `kyverno` | 1.18.1 | The Kyverno CLI: applies and tests Kyverno policies. | No task |
| `pipx:check-jsonschema` | 0.38.2 | Validates YAML and JSON files against a JSON schema. mise installs it with uv, from PyPI. | `schemas:check`, `schemas:test` |
| `pre-commit` | 4.7.0 | Runs the hooks of `.pre-commit-config.yaml`. | The Git hooks |
| `python` | 3.15.1 | Python runtime. The workflows install it before `pipx:check-jsonschema`. | No task |
| `shellcheck` | 0.11.0 | Linter for shell scripts. | `lint:shell` |
| `shfmt` | 3.14.1 | Formatter for shell scripts. | `lint:shell` |
| `terraform` | 1.17.0 | Applies the Terraform code of `instances/` and `modules/`. | The instance tasks, `lint:terraform`, `tf:lock` |
| `terraform-docs` | 0.24.0 | Writes the input and output tables of a Terraform module. | `tf:docs`, `doc:generate` |
| `tflint` | 0.65.0 | Linter for Terraform code. | `lint:terraform` |
| `trivy` | 0.76.1 | Scanner for vulnerabilities and configuration errors. | No task |
| `typos` | 1.51.1 | Spell checker for source code. | No task. The `typos` pre-commit hook uses its hook repository at `v1.51.1`. |
| `uv` | 0.13.3 | Python package installer. mise uses it to install the `pipx:` tools ([mise: pypi backend](https://mise.jdx.dev/dev-tools/backends/pypi.html)). | `pipx:check-jsonschema` |
| `vale` | 3.25.1 | Prose linter. It checks the Markdown files against the styles in `.vale/styles/`. | `lint:docs` |
| `yq` | 4.54.1 | YAML processor. | `manifests:render`, `schemas:check`, `schemas:test`, `labels:sync` |
| `zizmor` | 1.31.1 | Security linter for GitHub Actions workflows. | `lint:actions` |

## Tools in CI

The workflows install only the tools that their tasks use, with `jdx/mise-action`:

| Workflow | Tools |
| --- | --- |
| `Lint` | `python`, `uv`, `pipx:check-jsonschema`, `yq`, `terraform`, `tflint`, `conftest`, `actionlint`, `zizmor`, `shellcheck`, `shfmt`, `vale` |
| `Validate Schemas` | `python`, `uv`, `pipx:check-jsonschema`, `yq` |
| `Validate Kubernetes Manifests` | `helm`, `kubeconform`, `yq` |

## Environment variables

The `[env]` section sets these variables for each command that mise runs:

| Variable | Value |
| --- | --- |
| `ANSIBLE_VERSION` | `11.4.0` |
| `ANSIBLE_CREATOR_VERSION` | `25.3.1` |

No task reads these variables.

## Tools that mise does not install

| Tool | Used by |
| --- | --- |
| `git` | All the tasks that read the files that Git tracks. |
| `docker` | The instance tasks of a Kind instance. Refer to [Instance tasks](instance-tasks.md#docker-runtime). |
| `kubectl` | `instance:down`, to remove the kubeconfig context of a Kind cluster. |

## Related pages

- [Mise tasks](mise-tasks.md): the tasks that use the tools.
- [Install the tools](../how-to/install-the-tools.md)
- [Run your first local cluster](../tutorials/run-your-first-local-cluster.md)
- [Automated updates](../explanation/automated-updates.md)
