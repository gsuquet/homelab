# AGENTS.md

This file is the single set of instructions for all coding agents in this repository: Claude Code, Codex and Antigravity. `CLAUDE.md` and `GEMINI.md` import this file. Do not put instructions in those files.

A folder can have its own `AGENTS.md`. Read it before you change files in that folder. Its rules add to the rules in this file.

## About this repository

This repository provisions my production homelab: a Raspberry Pi 4 cluster. It also holds demo and test instances, for example Kind, GKE and Azure. Each instance uses the same modules.

The repository is in migration to a new design. The new design uses `modules/`, `instances/` and `gitops/`. Some folders still use the old design (`ansible/`, `kubernetes/`). Do not add new code to `ansible/`. The migration removes Ansible.

## Rules

1. Run `mise run lint` before you commit. The `Lint` workflow runs the same task. A pull request (PR) cannot merge when it fails.
2. Pin each dependency to an exact version. Use a commit SHA for GitHub Actions and pre-commit hooks, and a digest for container images. The Conftest policies in `policy/` check this.
3. Do not edit the files in `kubernetes/**/manifests/`. Change `sources/Chart.yaml` or `sources/values.yaml`, then run `mise run manifests:render`.
4. Do not commit secrets. A Kubernetes `Secret` in Git must have no `data` and no `stringData`, or it must be encrypted with SOPS (a top-level `sops` key, and each value starts with `ENC[`). A Conftest policy checks this. Refer to [Policies](docs/reference/policies.md).
5. Write all text in English. Write documentation in ASD-STE100 (Simplified Technical English) and put it in the correct Diátaxis section of `docs/`. Do not write RFCs or ADRs. `mise run lint:docs` checks the word list and the sentence rules. Refer to [Writing rules](docs/reference/writing-rules.md).
6. Use Conventional Commits for commit messages and PR titles, for example `feat(cilium): enable host firewall`. Sign each commit.
7. When you change a Terraform module, run `mise run doc:generate`. When you change a provider version, run `mise run tf:lock`.
8. When you add a rule, add a check for it. Prefer a schema, a policy or a linter to a written rule.

## How we work

The full rules are in [How we work (reference)](docs/reference/how-we-work.md). The reasons are in [How we work (explanation)](docs/explanation/how-we-work.md).

1. Each PR is atomic. It closes one issue (`Closes #N`), has one subject, and passes `mise run lint` alone. Create the issue first, and add it to the project "Perso".
2. A new subject starts with the docs. The doc PR adds the explanation, reference and how-to pages of the thing to build. My merge of the doc PR approves the design. Then the implementation PRs add the code and the tests, and they keep the docs true.
3. A spike is optional. It is a throwaway experiment on `kind-local`, on a `spike/<topic>` branch that never merges. Put the findings in a comment on the issue.
4. A small, reversible change needs no doc-first step, for example a change to `kind-local`, to the tooling, or a bug fix. Update the reference pages that the change makes wrong in the same PR.

## Review policy

An agent does not review its own work. A different agent reviews each PR.

- One review round is the default. A second round occurs only after a HIGH finding. A NIT never blocks a PR.
- Answer each finding that is not a NIT with a change or with a reason in the PR.
- When you and the reviewer do not agree on a HIGH finding, add `state/needs-decision` and set the Status to `Final review`. I decide.
- Write in the PR description which agent made the change and which agent reviewed it.

I merge each PR. Agents never merge, also not with auto-merge. The only exception is the Renovate automerge of dev tool PRs and the mise lock file, after all the required checks pass. Refer to "Renovate automerge" in [How we work (reference)](docs/reference/how-we-work.md#renovate-automerge).

Agents open PRs with my GitHub account. Thus GitHub cannot enforce these rules for agents. Each agent must obey them. A ruleset on `main` requires the `Run every linter and check` status.

Agents can push branches, edit the description of their PRs and mark their PRs ready after the review. Agents never push to `main`, never push tags, never force-push, never delete remote branches or tags, and never change settings or rulesets. Only I apply changes to cloud accounts.

## Tools and tasks

`.mise/config.toml` pins all the tools. Run `mise install`. The tasks are in `.mise/tasks/`. Refer to [Mise tasks](docs/reference/mise-tasks.md).
