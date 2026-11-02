# AGENTS.md

This file is the single set of instructions for all coding agents in this repository: Claude Code, Codex and Antigravity. `CLAUDE.md` and `GEMINI.md` import this file. Do not put instructions in those files.

A folder can have its own `AGENTS.md`. Read it before you change files in that folder. Its rules add to the rules in this file.

## About this repository

This repository provisions my production homelab: a Raspberry Pi 4 cluster. It also holds demo and test instances, for example Kind, GKE and Azure. Each instance uses the same modules.

The repository is in migration to a new design. The new design uses `modules/`, `instances/` and `gitops/`. Some folders still use the old design (`ansible/`, `kubernetes/`). Do not add new code to `ansible/`. The migration removes Ansible.

## Rules

1. Run `mise run lint` before you commit. The `Lint` workflow runs the same task. Do not ask for the merge of a pull request (PR) while it fails.
2. Pin each dependency to an exact version. Use a commit SHA for GitHub Actions and pre-commit hooks, and a digest for container images. The Conftest policies in `policy/` check this.
3. Do not edit the files in `kubernetes/**/manifests/`. Change `sources/Chart.yaml` or `sources/values.yaml`, then run `mise run manifests:render`.
4. Do not commit secrets. A Kubernetes `Secret` in Git must have no `data` and no `stringData`, or it must be encrypted with SOPS (a top-level `sops` key, and each value starts with `ENC[`). A Conftest policy checks this. Refer to [Policies](docs/reference/policies.md).
5. Write all text in English. Write documentation in ASD-STE100 (Simplified Technical English) and put it in the correct Diátaxis section of `docs/`. Use the language of the page type, with no author voice, and start from the template of the type in `docs/templates/`. Put each decision and its reason in an explanation page, not in a separate decision file. `mise run lint:docs` fails on the word list and the voice rules. The sentence rules are warnings: run `vale <file>` to see them. Refer to [Writing rules](docs/reference/writing-rules.md).
6. Use Conventional Commits for commit messages and PR titles, for example `feat(cilium): enable host firewall`. Sign each commit.
7. When you change a Terraform module, run `mise run doc:generate`. When you change a provider version, run `mise run tf:lock`.
8. When you add a rule, add a check for it. Prefer a schema, a policy or a linter to a written rule.

## How we work

The full rules are in [How we work (reference)](docs/reference/how-we-work.md). The reasons are in [How we work (explanation)](docs/explanation/how-we-work.md).

1. Each PR is atomic. It closes one issue (`Closes #N`), has one subject, and passes `mise run lint` alone. Create the issue first, and add it to the project "Perso".
2. A new subject starts with the docs. The doc PR adds the explanation, reference and how-to pages of the thing to build. My merge of the doc PR approves the design. Then the implementation PRs add the code and the tests, and they keep the docs true.
3. A spike is optional. It is a throwaway experiment on `kind-local`, on a `spike/<topic>` branch that never merges. Put the findings in a comment on the issue. After the findings, I delete the branch.
4. A small, reversible change needs no doc-first step, for example a change to `kind-local`, to the tooling, or a bug fix. Update the reference pages that the change makes wrong in the same PR.

## Review policy

An agent does not review its own work. A different agent reviews each PR.

- Each finding has a severity: HIGH, FIX or NIT. Fix each HIGH finding. Fix each FIX finding, or answer it with a reason in the PR. A NIT never blocks a PR.
- One review round is the default. A second round occurs only after a HIGH finding.
- When you and the reviewer do not agree on a HIGH or a FIX finding, add `state/needs-decision` and set the Status to `Final review`. I decide.
- Write in the PR description which agent made the change and which agent reviewed it.

I merge each PR. The only exception is the Renovate automerge of dev tool PRs and the mise lock file, after all the required checks pass. Refer to "Renovate automerge" in [How we work (reference)](docs/reference/how-we-work.md#renovate-automerge).

Agents open PRs with my GitHub account. Thus GitHub cannot enforce these rules for agents. Each agent must obey them. The ruleset on `main` does not require a status check yet. The required checks come with #201.

Agents can edit the description of their PRs, and mark their PRs ready after the review. Only I apply changes to cloud accounts.

## Push and merge limits

- Push only branch refs, and only to remotes under `github.com/gsuquet/`. Never push to `main` or to another default branch.
- Open a PR only when its base repository is under `github.com/gsuquet/`.
- Never merge a PR (`gh pr merge`), also not with auto-merge (`--auto`).
- Never force-push, in any form: `--force`, `-f`, `--force-with-lease` or a `+` reference.
- Never push tags. Never delete remote branches or tags (`--delete`, `:branch`). Never use `--mirror` or `--all`.
- Never use `--no-verify`.
- Never change the settings, the rulesets or the projects of a repository, unless the request names one specific change. To add an item to the project "Perso" and to move items on the board is permitted.
- When a hook, a ruleset, a guard or a check refuses an action, stop and report it. Do not find another way to do the action.

## Tools and tasks

`.mise/config.toml` pins all the tools. Run `mise install`. The tasks are in `.mise/tasks/`. Refer to [Mise tasks](docs/reference/mise-tasks.md).
