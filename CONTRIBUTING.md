# Homelab contributing guide

## Welcome

This guide tells how to change the homelab repository. A person and coding agents (Claude Code, Codex and Antigravity) make the changes. Agents also read [AGENTS.md](AGENTS.md).

The repository accepts these contributions:

- Bug reports and questions. Refer to [Report issues and bugs](#report-issues-and-bugs).
- Changes to the code, the checks and the docs. Refer to [Environment setup](#environment-setup), [Checks](#checks) and [Pull requests](#pull-requests).

The repository does not accept these contributions:

- New files in the legacy folders `ansible/` and `kubernetes/`. Refer to [Repository structure](docs/reference/repository-structure.md#legacy-folders).
- A pull request (PR) with no issue. The issue exists before the branch.
- A vulnerability report in a public issue. Obey the [security policy](https://github.com/gsuquet/.github/blob/main/SECURITY.md).

## Homelab overview

The repository holds the code of a personal Kubernetes platform: Terraform modules, instances and the GitOps sources of Argo CD. Refer to [README.md](README.md) and the [documentation index](docs/index.md).

## Ground rules

- Obey the [code of conduct](https://github.com/gsuquet/.github/blob/main/CODE_OF_CONDUCT.md).
- Obey the [Work rules](docs/reference/work-rules.md) for each change: the plans, the issues, the branches, the PRs, the review, the commits and the merge. The reasons are in [How we work](docs/explanation/how-we-work.md).

## Share ideas

1. Search the [issues](https://github.com/gsuquet/homelab/issues) for the same idea.
2. If no issue has it, open an issue. Tell the goal and the problem that it solves.

A new subject starts from a plan, before the docs and the code. Refer to [Work rules](docs/reference/work-rules.md#workflow-steps).

## Before you start

Make sure that you have:

- the [project dependencies](README.md#project-dependencies) of the README;
- a GitHub account;
- a Git configuration that signs your commits. Each commit has a signature that GitHub can verify. Refer to [Commits and the merge](docs/reference/work-rules.md#commits-and-the-merge).

## Environment setup

1. Clone the repository, and go to its root:

   ```bash
   git clone https://github.com/gsuquet/homelab.git
   cd homelab
   ```

2. Install the pinned tools and the Git hooks:

   ```bash
   mise install
   pre-commit install --install-hooks
   pre-commit install --hook-type commit-msg
   ```

3. Run the checks one time, to make sure that the tools work:

   ```bash
   mise run lint
   ```

`.mise/config.toml` pins each tool to an exact version, and `.mise/mise.lock` holds the checksums. Refer to [Install the tools](docs/how-to/install-the-tools.md) and [Tools](docs/reference/tools.md). For problems with the local cluster, refer to [Troubleshoot the local cluster](README.md#troubleshoot-the-local-cluster).

## Best practices

The standards are checks, not only text. When you add a rule, add a check for it in the same PR. Prefer a schema, a policy or a linter to a written rule.

### Checks

`mise run lint` runs the tasks of this table, and also `lint:records-test` and `schemas:test`. The pre-commit hooks run the same tasks, and also gitleaks, typos, yamllint and commitlint.

| Check | Task | Reference |
| --- | --- | --- |
| Terraform format and TFLint | `mise run lint:terraform` | [Mise tasks](docs/reference/mise-tasks.md) |
| Conftest policies | `mise run lint:policy` | [Policies](docs/reference/policies.md) |
| GitHub Actions workflows | `mise run lint:actions` | [Mise tasks](docs/reference/mise-tasks.md) |
| Shell scripts | `mise run lint:shell` | [Mise tasks](docs/reference/mise-tasks.md) |
| Documentation language | `mise run lint:docs` | [Writing rules](docs/reference/writing-rules.md) |
| References to old record files | `mise run lint:records` | [Mise tasks](docs/reference/mise-tasks.md) |
| `module.yaml`, `instance.yaml` and `cluster.yaml` | `mise run schemas:check` | [Schemas](docs/reference/schemas.md) |

The `Lint` workflow also runs `mise run doc:check`. The `Validate Schemas` and `Validate Kubernetes Manifests` workflows run on the changes to their files.

### Specific changes

| Change | Also do this |
| --- | --- |
| A Helm chart or values in `gitops/**/sources/` or `gitops/clusters/*/values/`, or a `gitops/clusters/*/cluster.yaml` | Run `mise run manifests:render`. Refer to [Render manifests](docs/how-to/render-manifests.md). |
| A Terraform module | Run `mise run doc:generate`. |
| A Terraform provider version | Run `mise run tf:lock`. Refer to [Change a Terraform provider version](docs/how-to/change-a-terraform-provider-version.md). |
| A tool version in `.mise/config.toml` | Run `mise lock`. |
| A new module | Copy `modules/_template/`. Read its `README.md`. |

## Content style guide

The docs use the [Diátaxis](https://diataxis.fr/) page types and ASD-STE100 (Simplified Technical English). The rules and the Vale checks are in [Writing rules](docs/reference/writing-rules.md). A new page starts from the template of its type in `docs/templates/`.

## Contribution workflow

The steps of a change are in [Make a change](docs/how-to/make-a-change.md). The rules are in [Work rules](docs/reference/work-rules.md).

### Fork and clone repositories

Agents and the `gsuquet` account push branches to the repository. Other contributors fork the repository on GitHub, then clone the fork. A PR from a fork targets `gsuquet/homelab`.

### Report issues and bugs

Open an issue at <https://github.com/gsuquet/homelab/issues>. Tell the command that you ran, the output and the result that you expected. An issue contains no secrets, private addresses or details of a weakness that is not corrected. Refer to [Public text and sources](docs/reference/work-rules.md#public-text-and-sources).

### Issue management

One issue is one task, and one task gives one PR. The fields of the project "Perso" are in [Work items](docs/reference/work-rules.md#work-items). The labels are in [Labels](docs/reference/work-rules.md#labels).

### Commit messages

Use [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/), for example `fix(cilium): set the API server port`. The `commit-msg` hook runs commitlint. Refer to [Commits and the merge](docs/reference/work-rules.md#commits-and-the-merge).

### Branch creation

Create a branch `<prefix>/<short-title>` from the current `main`. The prefix is a Conventional Commits type, for example `feat` or `docs`. Refer to [Branches](docs/reference/work-rules.md#branches).

### Pull requests

- Open the PR as a draft, with `Closes #<issue>` in its description. Fill in the sections of `.github/pull_request_template.md`.
- A reviewer that is not the author reviews the PR. Refer to [Review](docs/reference/work-rules.md#review).
- After the review, mark the PR ready for review. A person merges it with a squash merge.

### Releases

The repository has no releases and no tags. `mise run changelog:generate` writes `CHANGELOG.md` from the commit messages with git-cliff.

### Text formats

The docs are Markdown files that stay compatible with an MkDocs site: one `#` title, relative links and standard Markdown. A diagram is a Mermaid code block or an SVG file. Refer to [Writing rules](docs/reference/writing-rules.md#file-format).
