# AGENTS.md

This file is the single set of instructions for all coding agents in this repository: Claude Code, Codex and Antigravity. `CLAUDE.md` and `GEMINI.md` import this file. Do not put instructions in those files.

A folder can have its own `AGENTS.md`. Read it before you change files in that folder. Its rules add to the rules in this file.

## About this repository

This repository provisions the production homelab: a Raspberry Pi 4 cluster. It also holds demo and test instances, for example Kind, GKE and Azure. Each instance uses the same modules.

The repository is in migration to a new design. Some folders still use the old design (`ansible/`, `terraform/`, `kubernetes/`). Do not add new code to `ansible/`. The migration removes Ansible.

## Rules

1. Run `mise run lint` before you commit. The `Lint` workflow runs the same task. A pull request (PR) cannot merge when it fails.
2. Pin each dependency to an exact version. Use a commit SHA for GitHub Actions and pre-commit hooks, and a digest for container images. The Conftest policies in `policy/` check this.
3. Do not edit the files in `kubernetes/**/manifests/`. Change `sources/Chart.yaml` or `sources/values.yaml`, then run `mise run manifests:render`.
4. Do not commit secrets. Do not commit a plain Kubernetes `Secret`. Use `kubeseal` to make a `SealedSecret`. Refer to [Manage secrets](docs/how-to/manage-secrets.md).
5. Write all text in English. Write documentation in ASD-STE100 (Simplified Technical English) and put it in the correct Diátaxis section of `docs/`. `mise run lint:docs` checks the word list and the sentence rules. Refer to [Writing rules](docs/reference/writing-rules.md).
6. Use Conventional Commits for commit messages and PR titles, for example `feat(cilium): enable host firewall`.
7. When you change a Terraform module, run `mise run doc:generate`. When you change a provider version, run `mise run tf:lock`.
8. When you add a rule, add a check for it. Prefer a schema, a policy or a linter to a written rule.

## Review policy

An agent does not review its own work. A different agent reviews each PR.

| Change | Who can approve the merge |
| --- | --- |
| Documentation only (`docs/`) | A reviewing agent |
| A test or demo instance only | A reviewing agent |
| The homelab, a module, CI, the standards, or this file | The repository owner |
| Renovate updates of dev tools (patch, minor, digest) | Automatic, after all checks pass |
| Renovate updates of charts, images and providers (patch, minor) | The repository owner. After the Kind tests exist: automatic, after all checks and the Kind tests pass |
| Renovate major updates | The repository owner |

Agents open PRs with the owner's GitHub account, and GitHub does not let an author approve their own PR. Thus GitHub cannot enforce this table. It is a rule that each agent must obey: do not merge a PR in an owner row. A ruleset on `main` requires the `Run every linter and check` status.

`.github/CODEOWNERS` contains the paths that need the owner. Write in the PR description which agent made the change and which agent reviewed it.

## Tools and tasks

`.mise/config.toml` pins all the tools. Run `mise install`. The tasks are in `.mise/tasks/`. Refer to [Mise tasks](docs/reference/mise-tasks.md).
