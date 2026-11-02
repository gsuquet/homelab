# AGENTS.md

This file is the single set of instructions for all coding agents in this repository: Claude Code, Codex and Antigravity. `CLAUDE.md` and `GEMINI.md` import this file. Do not put instructions in those files.

A folder can have its own `AGENTS.md`. Read it before you change files in that folder. Its rules add to the rules in this file.

## About this repository

This repository provisions the production homelab: a Raspberry Pi 4 cluster. It also holds demo and test instances, for example Kind, GKE and Azure. Each instance uses the same modules.

The repository is in migration to a new design. The new design uses `modules/`, `instances/` and `gitops/`. Some folders still use the old design (`ansible/`, `kubernetes/`). Do not add new code to `ansible/`. The migration removes Ansible.

## Rules

1. Run `mise run lint` before you commit. The `Lint` workflow runs the same task.
2. Pin each dependency to an exact version. Use a commit SHA for GitHub Actions and pre-commit hooks, and a digest for container images. The Conftest policies in `policy/` check this.
3. Do not edit the files in `kubernetes/**/manifests/`. Change `sources/Chart.yaml` or `sources/values.yaml`, then run `mise run manifests:render`.
4. Do not commit secrets. A Kubernetes `Secret` in Git must have no `data` and no `stringData`, or it must be encrypted with SOPS (a top-level `sops` key, and each value starts with `ENC[`). A Conftest policy checks this. Refer to [Policies](docs/reference/policies.md).
5. Write all text in English. Write documentation in ASD-STE100 (Simplified Technical English) and put it in the correct Diátaxis section of `docs/`. Use the language of the page type, with no author voice, and start from the template of the type in `docs/templates/`. Put each decision and its reason in an explanation page, not in a separate decision file. `mise run lint:docs` fails on the word list and the voice rules. The sentence rules are warnings: run `vale <file>` to see them. Refer to [Writing rules](docs/reference/writing-rules.md).
6. Write commit messages and pull request (PR) titles as [Work rules](docs/reference/how-we-work.md#commits-and-the-merge) tells.
7. When you change a Terraform module, run `mise run doc:generate`. When you change a provider version, run `mise run tf:lock`.
8. When you add a rule, add a check for it. Prefer a schema, a policy or a linter to a written rule.

## How we work

Obey [Work rules](docs/reference/how-we-work.md) for each change. It holds the rules for the plans, the issues, the branches, the PRs, the review, the commits and the merge. The reasons are in [How we work](docs/explanation/how-we-work.md). The steps are in [Make a change](docs/how-to/make-a-change.md).

## Push and merge limits

These limits are safety rules, so this file repeats all of them. The source is "Push and merge limits of the agents" in [Work rules](docs/reference/how-we-work.md#push-and-merge-limits-of-the-agents). When the two do not agree, obey the stricter rule, and report the difference.

- Push only branch refs, and only to remotes under `github.com/gsuquet/`. Never push to `main` or to another default branch.
- Open a PR only when its base repository is under `github.com/gsuquet/`. A PR from a fork targets the parent repository by default.
- Never merge a PR (`gh pr merge`), also not with auto-merge (`--auto`).
- Never force-push, in any form: `--force`, `-f`, `--force-with-lease` or a `+` reference.
- Never push tags. Never delete remote branches or tags (`--delete`, `:branch`). Never use `--mirror` or `--all`.
- Never use `--no-verify`.
- Never change the settings, the rulesets or the projects of a repository, unless the request names one specific change. An agent can add an item to the project "Perso" and move items on it.
- When a hook, a ruleset, a guard or a check refuses an action, stop and report it. Do not find another way to do the action, for example `--no-verify`, the API, or a deletion and a new creation.

## Tools and tasks

`.mise/config.toml` pins all the tools. Run `mise install`. The tasks are in `.mise/tasks/`. Refer to [Mise tasks](docs/reference/mise-tasks.md).
