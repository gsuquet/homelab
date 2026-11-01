---
rfc: "0002"
status: review
start-date: 2026-10-31
pr: 167
---

# RFC 0002: How we work

## Summary

This RFC defines how the owner and the agents plan, track, write, review and merge work in this repository. A GitHub Projects board, issues and milestones hold all the plans. A milestone is a feature that a person can measure. Each task is one issue and one atomic PR. The work on a subject goes in a fixed order: RFC, ADR, Diátaxis documentation, interface specification, tests, code. A new reviewing agent reviews each PR, and the loop continues until no finding stays open. Only the owner merges, with one exception for Renovate. The RFC also defines the label taxonomy, the issue forms, the push rules, the merge method and signed commits. Git hooks, CI checks, Conftest policies and GitHub rulesets enforce the rules, so that the rules do not depend on the features of one agent. Agent identity is out of scope, and a later RFC handles it.

## Motivation

[RFC 0001](0001-records-process.md) defines how the repository records decisions. It does not define how the work moves from a plan to a merged PR. Today, that part has these problems:

- **The plans are outside of the repository.** The implementation plan and the related plans are Claude Docs documents. An agent that works in the repository cannot read them with `gh`, and the PRs do not link to them.
- **No issue or milestone tracks the work.** The repository has two issues: the Renovate dependency dashboard, and a closed Renovate issue. The project "Perso" exists, but it holds no item. The owner and the agents cannot see what is in progress, what waits for a review, or what waits for the owner.
- **The labels have no system.** The repository has the nine default GitHub labels. The PR labeler sets `ci`, `github_actions`, `configuration`, `gitignore` and `documentation`, and Renovate sets `renovate`. The labeler configuration refers to files that do not exist, for example `justfile`, `.semrelrc` and `.github/ISSUE_TEMPLATE/`.
- **The rules of work are in `AGENTS.md` only.** [ADR 0001](../adrs/0001-use-rfcs-and-adrs-to-record-decisions.md) tells that these rules have no decision authority until an RFC confirms them.
- **Some rules and checks do not agree.** The section "Current state" gives the details.

### Current state

The author read the settings of the repository and of the project with `gh` on 2026-10-31. This RFC only describes these settings. The owner changes them in the rollout.

| Subject | Value today |
| --- | --- |
| Merge methods | Squash and rebase are on. Merge commits are off. |
| Squash commit title and message | `COMMIT_OR_PR_TITLE` and `COMMIT_MESSAGES`. With one commit, the commit title goes to `main`, not the PR title. |
| Branch after merge | GitHub deletes it. |
| Auto-merge of the repository | On. The dev tool rule of Renovate has `platformAutomerge: false`, so Renovate merges those PRs through the API itself. The default of `platformAutomerge` is `true`, and the lock file maintenance PRs do not change it. Thus these PRs can use the auto-merge of GitHub. No lock file maintenance PR merged yet. |
| Ruleset `main` | Block deletion, block force push, restrict creation, require signed commits, require linear history, require a PR. |
| PR rule of the ruleset | Code owner review, resolution of review threads, dismissal of old approvals, zero approvals. `require_extra_approval_for_unattributed_changes: true`, a preview setting for Copilot PRs, with no effect at zero approvals. Merge methods: squash and rebase. |
| Code owner review in practice | The owner is the only code owner and the author of each PR. PR #165 changed `docs/records/` and `CODEOWNERS`, and it merged with no review. Thus the rule does not block a PR whose author is the only code owner. The author found no GitHub page that tells this. RFC 0003 proposes to remove `CODEOWNERS`. |
| Required status checks | None. `AGENTS.md` tells that the ruleset requires `Run every linter and check`, but the ruleset has no such rule. |
| Bypass list of the ruleset | Empty. |
| Tag rulesets | None. The repository has no tags. |
| Signatures on `main` | The last 30 commits have the committer `GitHub`, and GitHub shows each one as verified. |
| Local Git configuration of the owner | `commit.gpgsign=true` and `gpg.format=openpgp`. Agents sign with the GPG key of the owner. |
| Token of `gh` | The classic token of the owner, with the scopes `repo`, `project`, `gist` and `read:org`. The owner is an administrator of the repository. Each agent that runs as the owner can use this token. |
| Renovate | The GitHub App `renovate-gsuquet` opens PRs and merges the dev tool PRs itself, for example #152, #153, #154 and #156. |
| Commit message check | `.pre-commit-config.yaml` holds the `commitlint` hook at the `commit-msg` stage, but the hook is not installed on the machine of the owner. No CI check. `.pre-commit-config.yaml` has no `default_install_hook_types`. |
| Git hooks on the machine of the owner | `pre-commit` comes from pre-commit. `commit-msg` and `pre-push` come from the Entire CLI, so `commitlint` does not run there today. |
| Issue templates | None. A PR template exists. |
| Private vulnerability reporting | On. |
| Projects | The user-level project #2 "Perso", private, with the description "Regroups and organizes work across all my personal projects/repositories". It has no item. |
| Fields of "Perso" | Status: `Backlog`, `Ready`, `In progress`, `In review`, `Done`. Priority: `P0`, `P1`, `P2`. Size: `XS`, `S`, `M`, `L`, `XL`. Estimate. Start date. End date. The built-in fields, for example Repository, Milestone and Reviewers. |
| Shared defaults | No `gsuquet/.github` repository. The `gsuquet/workflows` repository holds reusable workflows, for example the labeler. |

The labeler labels have the color `#ededed` and no description. Thus GitHub made them when the labeler first used them. Renovate puts the `security` label on vulnerability PRs. That label does not exist yet, and it can appear in the same way with the first vulnerability PR.

### Use cases

- **The owner starts a new subject.** The owner opens an issue with the RFC form. The issue goes on the board in `Backlog`. The owner and an agent refine it, and the issue moves to `Ready`.
- **An orchestrating agent plans a milestone.** It reads the milestone and its acceptance criteria with `gh`. It finds the issues in `Ready`, and it gives each one to an implementing agent.
- **An implementing agent finishes a task.** It opens a draft PR that closes the issue. A new reviewing agent reviews the PR. The loop continues until no finding stays open. Then the PR waits for the owner.
- **The owner has ten minutes.** The owner opens the "Owner queue" view of the board and sees only the PRs and the decisions that wait for the owner.
- **A reader asks if a milestone is complete.** Each acceptance criterion names a check. The reader runs the checks or reads the results in CI.
- **The owner uses a different agent.** Claude Code, Antigravity or a local LLM does the task. The same Git hooks, CI checks and rulesets apply to each one.

## Proposal

### Roles

```mermaid
flowchart LR
    O[Owner] -->|refines subjects, decides, merges| R[(Repository)]
    OR[Orchestrator] -->|plans, gives tasks| I[Implementing agent]
    I -->|branch, commits, draft PR| R
    OR -->|starts a new agent| V[Reviewing agent]
    V -->|findings on the PR| R
    I -->|fixes, asks for a new review| OR
```

In text: the owner refines subjects, makes decisions and merges. The orchestrator plans the work and gives the tasks. The implementing agent writes the change in a draft PR. A reviewing agent reviews it. The implementing agent fixes the findings and asks for a new review.

| Role | Who | Can do | Must not do |
| --- | --- | --- | --- |
| Owner | The owner of the repository | Refine subjects. Accept or refuse records. Merge PRs. Change settings and rulesets. Close milestones. | Nothing in this RFC limits the owner. |
| Orchestrator | An agent, or the owner | Split a milestone into issues. Give an issue to an implementing agent. Start a reviewing agent. Move items on the board. | Merge. Change settings or rulesets. Do the review of a PR that it implemented. |
| Implementing agent | An agent | Push a branch. Open a draft PR. Fix review findings. Mark a PR ready for review when no finding stays open. | Merge. Push to `main`. Push tags. Force-push. Delete a remote branch or tag. Change settings or rulesets. Review its own work. |
| Reviewing agent | A new agent, with no context of the implementation | Read the PR, run the checks, write findings. | Change the branch. Merge. |
| Renovate | The GitHub App `renovate-gsuquet` | Open dependency PRs. Merge the PRs that "The Renovate exception" lists, after the required checks pass. | Merge other PRs. |

One agent can be the orchestrator and the implementing agent of the same task. The reviewing agent is always a different agent from the implementing agent, as [ADR 0005](../adrs/0005-use-the-rfc-and-adr-lifecycle-and-flow.md) requires.

This RFC replaces the review policy table of `AGENTS.md`. In that table, a reviewing agent can approve the merge of documentation and test instance PRs. With this RFC, a reviewing agent approves only the end of the review loop, and the owner merges each PR. This rule does not use `CODEOWNERS`. RFC 0003 proposes to remove that file. ADR 0005 has no partial supersede. Thus a derived ADR of RFC 0003 restates [ADR 0001](../adrs/0001-use-rfcs-and-adrs-to-record-decisions.md) without `CODEOWNERS`, and it supersedes ADR 0001 in full.

### The work items

```mermaid
flowchart TD
    M[Milestone: one measurable feature] --> I1[Issue: one task]
    M --> I2[Issue: one task]
    I1 --> S1[Sub-issue: optional]
    I1 --> P1[PR: one task, closes the issue]
    S1 --> P2[PR]
    I2 --> P3[PR]
    B[Projects board] -. holds .-> I1
    B -. holds .-> I2
    B -. holds .-> P1
```

In text: a milestone holds issues. An issue holds one task, and it can have sub-issues. One PR closes one issue. The board holds all the issues and PRs.

- A **milestone** is one feature that a person can measure. It has a description, acceptance criteria and, as an option, a due date. The format is in "Milestones".
- An **issue** is one task. A task gives one PR. When a task needs more than one PR, it becomes a parent issue with one sub-issue for each PR. GitHub permits up to 100 sub-issues for each parent, and eight levels.
- A **PR** does one task. Its description has `Closes #N` for its issue. GitHub closes the issue when the PR merges into `main`.
- The **board** is a GitHub Projects project. It holds each open issue and PR, and it shows their state.

### The order of work

For each subject, the work goes in this order. Each step is one or more atomic PRs.

```mermaid
flowchart LR
    A[RFC] --> B[ADR]
    B --> C[Diátaxis documentation]
    C --> D[Interface specification]
    D --> E[Tests]
    E --> F[Code]
```

In text: RFC, then ADR, then Diátaxis documentation, then an interface specification, then tests, then code.

1. **RFC.** The proposal and its discussion. [ADR 0005](../adrs/0005-use-the-rfc-and-adr-lifecycle-and-flow.md) gives the flow.
2. **ADR.** The decisions from the accepted RFC.
3. **Diátaxis documentation.** The how-to guides, the reference pages and the explanation pages that tell the target behavior. Write the documentation before the code, so that the code has a written target.
4. **Interface specification.** The contract of the change, in a format that a tool can read. For an HTTP API, an OpenAPI document. For a module or an instance, its JSON schema in `schemas/`. For a Helm chart, its `values.schema.json`. For a policy, the Conftest test data.
5. **Tests.** The tests that the code must pass. For example, `conftest verify`, `terraform test`, schema tests or Kind tests.
6. **Code.** The implementation that makes the tests pass.

The author skips a step that does not apply, and tells why in the PR description. For example, a change of the CI workflow has no interface specification. A plain bug fix, as ADR 0001 defines it, starts at the tests.

ADR 0001 and ADR 0005 permit implementation commits in an ADR PR, before the owner decides. This RFC does not change that rule. When an ADR PR holds implementation commits, the commits follow the same order: documentation, then specification, then tests, then code. Each later step goes in its own atomic PR.

### Milestones

The owner defines a milestone as a **measurable feature**: a result that a person or a check can confirm. "Migrate to Talos" is not a milestone. "The Raspberry Pi cluster runs Talos, and Argo CD syncs all the applications" is a milestone, if each part has a check.

A milestone has these parts:

- **Title.** The feature, in a short sentence. Example: `Secrets: SOPS and External Secrets Operator`.
- **Description.** The goal in one paragraph, the links to the RFCs and ADRs, and the acceptance criteria.
- **Acceptance criteria.** A numbered list in the description. Each criterion has the format below.
- **Due date.** An option. The roadmap view of the board uses it.

```text
## Acceptance criteria

1. <Observable result>.
   Check: <command, CI job or test that shows the result>.
2. No Secret in Git has data that is not encrypted.
   Check: `mise run lint:policy` passes in CI.
```

A criterion without a check is not complete. If a check does not exist yet, an issue in the milestone adds it.

An issue goes into a milestone when its PR helps to meet a criterion. Each issue has one milestone at most. An issue without a milestone stays in `Backlog`. The owner closes a milestone when GitHub shows no open issue in it and all its checks pass.

The owner decided on 2026-11-01: one milestone for each feature, with its RFCs as issues in it. A wave of RFCs is a plan of the order of work, not a feature, and an RFC alone is not measurable. Example: "Secrets: SOPS and External Secrets Operator" holds the RFC, the ADRs, the documentation, the tests and the code.

This RFC does not set the list of milestones. The owner and the author make the list together, after the acceptance of this RFC. The candidate source is the order of the RFC waves:

- Wave 1: how we work (this RFC), the repository structure (RFC 0003), the reference of Kubernetes labels and annotations (RFC 0004).
- Wave 2: tooling and dependency pinning, secrets with SOPS and External Secrets Operator.
- Wave 3: zero-trust networking, agents.
- Wave 4: the security baseline, tenants.
- Wave 5: OpenChoreo self-service.
- The migration of the Raspberry Pi cluster to Talos.

### Atomic PRs

An atomic PR does one task. It has these properties:

- It closes one issue, or one sub-issue, with `Closes #N` in its description. The owner decided on 2026-11-01 that a record gets no `issue` field in its front matter. The PR of the record closes the issue.
- It has one subject. A reviewer can give one decision about it: merge or change.
- It passes `mise run lint` alone. It does not need a later PR to pass the checks.
- It does not mix a refactoring with a change of behavior.
- An RFC PR holds only the RFC and its index row. An ADR PR holds the ADRs, their index rows and, as ADR 0001 permits, implementation commits.
- A PR after the ADR step links to its ADRs, as ADR 0005 requires.

A PR can have more than one commit. The squash merge makes one commit on `main` from them.

### The review loop

```mermaid
sequenceDiagram
    actor Owner
    participant Orch as Orchestrator
    participant Impl as Implementing agent
    participant Rev as Reviewing agent (new each round)
    Orch->>Impl: Give the issue
    Impl->>Impl: Branch, commits, mise run lint
    Impl->>Impl: Open a draft PR (Closes #N)
    loop Until no finding stays open
        Impl->>Orch: Ask for a review
        Orch->>Rev: Start a new reviewing agent
        Rev-->>Impl: Findings on the PR
        Impl->>Impl: Fix each finding, or record a reason
        opt Disagreement after one more round
            Impl->>Owner: Add state/needs-owner, set Owner review, PR stays a draft
            Owner-->>Impl: Decision on the open findings
            Impl->>Impl: Apply the decision, remove state/needs-owner
        end
    end
    Impl->>Owner: Mark the PR ready for review
    loop Until each comment has an answer
        Owner->>Impl: Comments
        Impl-->>Owner: Change or reason
    end
    Owner->>Owner: Squash merge
```

In text: the orchestrator gives the issue to the implementing agent. The agent opens a draft PR. The orchestrator starts a new reviewing agent. The implementing agent fixes each finding or records a reason, and asks for a new review. When no finding stays open, the agent marks the PR ready. If the implementer and the reviewer still disagree, the owner decides on the open findings. The agent applies the decision, removes `state/needs-owner`, and asks for a new review of the change. The loop continues until no finding stays open. The owner comments, the agent answers, and the owner merges.

The rules of the loop:

- The owner decided on 2026-11-01: a new reviewing agent for each round. It gets a detailed brief: the PR, the issue, the linked records and the findings of the earlier rounds with their answers. It does not get the conversation of the implementing agent. Thus its review does not depend on the reasons of the implementer.
- The reviewer ranks each finding: security, then correctness, then performance, then readability, then style.
- The implementing agent answers each finding with a change or with a reason in the PR.
- A finding with a recorded reason does not stay open, unless the next reviewer refuses the reason.
- If the reviewer and the implementer still disagree after one more round, the implementer adds `state/needs-owner` and sets the Status to `Owner review`. The PR stays a draft. The decision of the owner closes the open findings. The implementer applies the decision, removes `state/needs-owner`, sets the Status to `In progress`, and asks for a new review of the change.
- The loop stops only when a review finds no open finding.
- This exit rule and the owner decision on a disagreement change the loop of [ADR 0005](../adrs/0005-use-the-rfc-and-adr-lifecycle-and-flow.md) (flow step 3). The change also applies to record PRs. ADR 0005 loops until the reviewer finds no problem. This RFC only proposes the change. A derived ADR must restate all of ADR 0005 and supersede it in full to make it a decision.
- The PR description names the implementing agent and each reviewing agent.
- The PR stays a draft during the loop. "Ready for review" means "ready for the owner".

### Push and merge rules

Agents can push branches and open PRs in the repositories under `github.com/gsuquet/`. These limits apply:

- Push a branch, never `main`. Each PR goes into `main` only through a merge of the owner.
- Never push a tag.
- Never force-push, in any form: `--force`, `-f`, `--force-with-lease` or a `+` reference.
- Never delete a remote branch or tag.
- Never merge a PR, also not with auto-merge.
- Never change the settings, the rulesets or the projects of a repository, unless the owner asks for one specific change.
- Open a PR only when the base repository is under `github.com/gsuquet/`.

An instruction file alone does not enforce a rule, and an agent hook works only for one agent. Thus four tools enforce these limits, for each agent:

| Tool | What it enforces | Limit |
| --- | --- | --- |
| GitHub rulesets | On `main`: no direct push, no force push, no deletion. On all branches: signed commits. On all tags: no creation, update or deletion. Required checks. | The token of the owner can change the rulesets. No ruleset blocks the deletion of other branches. |
| Git hooks | A plain Git `pre-push` script refuses a push to `main`, a tag, a deletion and a non-fast-forward push. The pre-commit `commit-msg` hook checks Conventional Commits. | `git push --no-verify` skips the hooks. |
| CI checks | `mise run lint`, the PR title check | Only on PRs and on `main`. |
| Conftest policies | The rules on the files, for example pinned versions and no secrets | Only on files. |

Agent hooks, for example the hooks of Claude Code, are an early convenience. They give a fast refusal before a command runs, but the four tools above are the controls. The design in "Detailed design" tells how to make these controls stronger while the agents use the account of the owner.

After Rollout step 5, the owner merges each PR with a squash merge, and the PR title becomes the commit title on `main`. Until then, a PR with one commit puts its commit title on `main`.

### The Renovate exception

Renovate is a tool, not an agent. It has its own identity, the GitHub App `renovate-gsuquet`. Today, `renovate.json` lets Renovate merge two types of PR without the owner:

- **Dev tool PRs.** The files are `.mise/config.toml`, `.pre-commit-config.yaml` and `.github/workflows/**`. The managers are `mise`, `pre-commit`, `github-actions` and `custom.regex`. The update types are `minor`, `patch`, `digest`, `pin` and `pinDigest`. Renovate merges them through the API (`platformAutomerge: false`).
- **Lock file maintenance PRs.** `lockFileMaintenance` has `automerge: true`. No file filter applies, so the PR can change `.mise/mise.lock`, the `.terraform.lock.hcl` files and `Chart.lock` files, for example `kubernetes/bootstrap/argo-cd/sources/Chart.lock`. These PRs keep the default `platformAutomerge: true`, so they use the auto-merge of GitHub.

The two types wait for different checks:

- With `platformAutomerge: false`, Renovate merges a dev tool PR only after the checks of the branch pass ([Renovate: automerge](https://docs.renovatebot.com/key-concepts/automerge/)).
- With `platformAutomerge: true`, GitHub merges the PR "after all (if any) branch policies have been met" ([Renovate: configuration options](https://docs.renovatebot.com/configuration-options/)). The Renovate automerge page warns that GitHub can then merge PRs with failing tests if the branch requires no status check.

Today, `main` has no required check. Thus a lock file maintenance PR can merge with no passing check, also for the Terraform provider locks and `Chart.lock`. This risk exists today. The author did not test what GitHub does in this case. If "Allow auto-merge" is off, Renovate merges through the API itself, after the checks of the branch. Thus that setting alone does not limit these PRs.

Major updates wait for the approval of the owner on the dependency dashboard. The author did not verify if `vulnerabilityAlerts` changes this for vulnerability PRs. Vulnerability PRs of majors still do not merge without the owner, because no rule gives them `automerge`.

`minimumReleaseAge` is three days. But `vulnerabilityAlerts` sets `minimumReleaseAge: null`, so a vulnerability PR of a dev tool can merge with no delay.

This RFC proposes these conditions for the exception:

- Renovate merges only the dev tool PRs with the files, managers and update types above.
- Lock file maintenance merges without the owner only for `.mise/mise.lock`. The provider and chart lock files reach the instances, so the owner merges them. `lockFileMaintenance` has no file filter. Thus the configuration sets `lockFileMaintenance.automerge: false` at the top level. One `packageRules` entry then sets `automerge: true` with `matchUpdateTypes: ["lockFileMaintenance"]` and `matchManagers: ["mise"]`. The entry also sets its own `branchTopic`, for example `mise-lock-file-maintenance`. Without it, Renovate puts all lock files in one `renovate/lock-file-maintenance` PR, and the result of two `automerge` values in one PR is not documented.
- The required status checks of Rollout step 5 exist before the exception applies.

The mise lock file maintenance runs `mise lock --bump`. A self-hosted Renovate must have `mise` in `allowedUnsafeExecutions` for this ([Renovate: mise manager](https://docs.renovatebot.com/modules/manager/mise/)). The owner must confirm the setup of `renovate-gsuquet`.

This PR does not change `renovate.json`. The risk of the lock file maintenance PRs exists today, so the orchestrator proposes a separate fix to the owner, outside of this RFC. The owner decides on it. A Conftest policy and a scheduled check then enforce the exception. Refer to Rollout step 10. The owner merges all the other Renovate PRs.

### Commits

Each commit message uses Conventional Commits 1.0.0. The PR title uses the same format, because it becomes the commit title on `main`.

Each commit on each branch has a signature that GitHub can verify. The ruleset of `main` already requires signed commits. An unsigned commit on the head branch can block the squash merge. The section "Signed commits" gives the details.

### Labels

Labels have a prefix and a name: `<prefix>/<name>`. Kubernetes uses the same format. Each prefix answers one question.

| Prefix | Question | Who sets it |
| --- | --- | --- |
| `kind/` | What is this item? | The issue form, or the labeler from the branch name |
| `area/` | Which part of the repository does it change? | The labeler, from the changed files |
| `state/` | Does something block it? | The owner or an agent |

Two labels have no prefix, because Renovate sets them: `renovate` and `security`.

The full list is in "Detailed design".

### Issue forms and the PR template

New issues use issue forms. The repository has three forms, plus a `config.yml` that hides the blank issue for readers:

- **Task.** One task in a milestone. It has the goal, the acceptance check, the step in the order of work and the links to the ADRs.
- **Bug.** The observed behavior, the expected behavior and the steps to see it.
- **RFC subject.** A subject that needs an RFC. The owner and an agent refine it before the RFC.

The PR template stays, with three new lines: the issue (`Closes #N`), the step in the order of work, and the links to the ADRs. The ADR line is mandatory for each step after the ADR step.

## Detailed design

### The Projects board

The board is a user-level GitHub Project of the owner. A project can hold issues and PRs from many repositories, up to 50,000 items ([GitHub: adding items to your project](https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-items-in-your-project/adding-items-to-your-project)). A project can have up to 50 fields, with the built-in fields included ([GitHub: about Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects)).

The owner decided on 2026-11-01: the existing project "Perso" holds the board, for all personal repositories. It is empty, so the change costs nothing, and its fields already match most of the target. The fields, the states and the views below are the target for "Perso". One auto-add workflow watches the homelab. The issue forms of the other repositories use the `projects` key. The 50-field limit applies to all repositories together.

#### Fields

| Field | Type | Values | Use | In "Perso" today |
| --- | --- | --- | --- | --- |
| Status | Single select (built-in) | `Backlog`, `Ready`, `In progress`, `Agent review`, `Owner review`, `Done` | The state of the item. Refer to "Workflow states". | Yes, with `In review` in place of the two review states |
| Priority | Single select | `P0`, `P1`, `P2` | The order of work in a milestone. The owner decided on a project field, not `priority/` labels. The agents read it with `gh project item-list`. | Yes |
| Size | Single select | `XS`, `S`, `M`, `L`, `XL` | A rough size. An `L` or `XL` item becomes a parent issue with sub-issues. | Yes |
| Step | Single select | `RFC`, `ADR`, `Docs`, `Spec`, `Tests`, `Code` | The step in the order of work. | No |
| Agent | Text | For example `Claude Code` | The agent that works on the item. | No |
| Start date, End date | Date | | The roadmap view. | Yes |
| Estimate | Number | | Not used by this process. | Yes |
| Milestone, Labels, Assignees, Repository, Reviewers, Linked pull requests, Parent issue, Sub-issues progress | Built-in | | Read from the issue or the PR. | Yes |

The fields come from [GitHub: understanding fields](https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields). Issue types are an organization feature, and this repository belongs to a personal account. Thus the `kind/` labels do the work of issue types.

#### Workflow states

```mermaid
stateDiagram-v2
    state "In progress" as InProgress
    state "Agent review" as AgentReview
    state "Owner review" as OwnerReview
    [*] --> Backlog
    Backlog --> Ready: refined, in a milestone
    Ready --> InProgress: an agent takes it
    InProgress --> AgentReview: draft PR open
    AgentReview --> InProgress: findings to fix
    AgentReview --> OwnerReview: no open finding, PR ready
    AgentReview --> OwnerReview: disagreement, state/needs-owner, PR stays a draft
    OwnerReview --> InProgress: owner decides or asks for changes
    OwnerReview --> Done: PR merged or issue closed
    Backlog --> Done: closed as not planned
    Done --> [*]
```

In text: an item starts in `Backlog`. It goes to `Ready` after the refinement, when it has a milestone. It goes to `In progress` when an agent takes it, and to `Agent review` when its draft PR is open. Findings send it back to `In progress`. With no open finding, it goes to `Owner review`. A disagreement also sends it to `Owner review`, with `state/needs-owner` and a draft PR. After a decision or a change request of the owner, it goes back to `In progress`, and the change gets a new review in `Agent review`. The merge moves it to `Done`. A closed issue also goes to `Done`.

| Status | Meaning | Who moves the item here |
| --- | --- | --- |
| `Backlog` | Not refined, or no milestone. | The built-in workflow, when an item comes into the project |
| `Ready` | Refined, in a milestone, and with a check. | The owner or the orchestrator |
| `In progress` | An agent works on it. | The implementing agent |
| `Agent review` | A draft PR is open. A reviewing agent reviews it. | The implementing agent |
| `Owner review` | The item waits for the owner: a PR with no open finding, or an item with `state/needs-owner`. | The implementing agent, or the agent that adds `state/needs-owner` |
| `Done` | Merged or closed. | The built-in workflows |

#### Views

| View | Layout | Filter or group |
| --- | --- | --- |
| Board | Board | Columns by `Status`. Group by `Milestone`. |
| Owner queue | Table | `status:"Owner review"`. Projects has no OR filter across fields ([GitHub: filtering projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/filtering-projects)). Thus each agent that adds `state/needs-owner` to an issue or a PR also sets the Status to `Owner review`. |
| Backlog | Table | `status:Backlog,Ready`. Sort by `Priority`. Group by `Milestone`. |
| Roadmap | Roadmap | The milestones and their end dates. |
| Agents | Table | `status:"In progress","Agent review"`. Group by `Agent`. |
| One view for each repository | Table | Filter by `Repository`. |

#### Automation

The project uses the built-in workflows only ([GitHub: built-in automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations)):

- An item that comes into the project gets `Backlog`.
- A closed issue or PR gets `Done`. GitHub enables this workflow by default.
- A merged PR gets `Done`. GitHub enables this workflow by default.
- Auto-add puts the new issues and PRs of the repository into the project. The plan of the account limits the number of auto-add workflows: 1 on Free, 5 on Pro ([GitHub: adding items automatically](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically)). Auto-add does not add the items that exist before it starts.
- Auto-archive removes `Done` items from the views after 14 days.

The built-in workflows cannot move an item to `Agent review` or `Owner review`. The owner decided on 2026-11-01: for now, the agents move the items with `gh project item-edit`, until the agent identity RFC. The `gh` token of the owner has the `project` scope since 2026-10-31. A fine-grained token cannot access a project that a user account owns ([GitHub: managing your personal access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)). "Perso" belongs to the user account, so this limit applies to control (a) below.

### Labels

#### Kind

| Label | Meaning | Branch prefix | Conventional Commits type of the PR |
| --- | --- | --- | --- |
| `kind/feature` | New behavior | `feat/` | `feat` |
| `kind/bug` | Wrong behavior | `fix/` | `fix` |
| `kind/docs` | Documentation only, not a record | `docs/` | `docs` |
| `kind/record` | An RFC or an ADR | `rfc/`, `adr/` | `docs` with the scope `records` |
| `kind/chore` | Maintenance, refactoring, CI, dependencies | `chore/`, `refactor/`, `ci/`, `build/`, `test/`, `perf/`, `style/`, `revert/`, `renovate/` | `chore`, `refactor`, `ci`, `build`, `test`, `perf`, `style`, `revert` |

The labeler sets the `kind/` label of a PR from the branch prefix in the table. `actions/labeler` v5 can match the head branch. The branch names follow the format `<prefix>/<issue or record number>-<short-title>`. Examples: `feat/42-sops-age-key`, `rfc/0002-how-we-work`, `adr/0007-0010-how-we-work`. Renovate uses its own `renovate/` branches. A branch with no known prefix gets no `kind/` label, and the reviewer adds one.

#### Area

The labeler sets the `area/` labels from the changed files. They replace `ci`, `github_actions`, `configuration`, `gitignore` and `documentation`.

| Label | Paths |
| --- | --- |
| `area/records` | `docs/records/**` |
| `area/docs` | `docs/**` except `docs/records/**`, `*.md` at the root |
| `area/ci` | `.github/**`, `.pre-commit-config.yaml`, `renovate.json` |
| `area/tooling` | `.mise/**`, `.vale/**`, `.vale.ini`, the linter configuration files |
| `area/modules` | `modules/**` |
| `area/instances` | `instances/**` |
| `area/gitops` | `gitops/**` |
| `area/policy` | `policy/**`, `schemas/**` |
| `area/legacy` | `ansible/**`, `kubernetes/**` |

#### State

| Label | Meaning |
| --- | --- |
| `state/blocked` | Another item or an outside event blocks this item. The description tells which. |
| `state/needs-owner` | The item waits for a decision of the owner. |

#### Labels from Renovate

| Label | Set by |
| --- | --- |
| `renovate` | Renovate, on each PR |
| `security` | Renovate, on vulnerability PRs |

The GitHub default labels go away. `bug` becomes `kind/bug`, `enhancement` becomes `kind/feature`, and `documentation` becomes `area/docs`. For `duplicate`, `invalid` and `wontfix`, GitHub can close an issue as "not planned" or as a duplicate. The repository has one owner, so `good first issue`, `help wanted` and `question` have no use.

#### Labels as code

A file, `.github/labels.yml`, holds the name, the color and the description of each label. A tool makes the labels of the repository equal to the file. The owner decided on 2026-11-01: a `mise` task that runs `gh label create --force` for each label, for now. A CI workflow can replace it later.

### Issue forms

The forms are in `.github/ISSUE_TEMPLATE/` ([GitHub: syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)).

| File | `labels` | Body |
| --- | --- | --- |
| `task.yml` | `kind/feature` | Goal (textarea, required). Acceptance check (textarea, required). Step in the order of work (dropdown, required). Links to the ADRs (textarea, required for each step after the ADR step). |
| `bug.yml` | `kind/bug` | What occurs (required). What must occur (required). Steps (required). Instance (dropdown). |
| `rfc.yml` | `kind/record` | Problem (required). Scope (required). Out of scope. Sources to read. |
| `config.yml` | | `blank_issues_enabled: false`. A contact link to `https://github.com/gsuquet/homelab/security/advisories/new`, the private vulnerability report form. |

An issue form cannot make a field required only for some dropdown values. Thus the reviewer checks the ADR links of a task, and the form text tells when they are mandatory.

The `projects` key of a form adds the new issue to the board. Its format is `gsuquet/<project-number>`. The person who opens the issue must have write access to the project. Auto-add does the same work for the other people.

A form adds a label only if the label exists. Thus the labels must exist before the forms.

### Signed commits

#### How GitHub verifies a signature

GitHub verifies GPG, SSH and S/MIME signatures ([GitHub: about commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification)):

- A **GPG** signature verifies when the GitHub account of the committer has the public key.
- An **SSH** signature verifies when the account has the public key as a "signing key". An "authentication key" is a different type. To use one SSH key for both, add it two times ([GitHub: adding a new SSH key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)).
- GitHub signs the commits that it makes in the web interface with its own key, `web-flow`. This includes the squash merge: each commit on `main` today has the committer `GitHub` and a valid signature.
- GitHub cannot sign the commits of a rebase merge, because it does not have the private key of the committer ([GitHub: about merge methods](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/about-merge-methods-on-github)).
- GitHub keeps the result of each verification. When a key expires or the owner removes it, the earlier commits stay verified. GitHub does not verify them again.
- A GitHub App or a bot can make a commit through the API as itself. If the request has no author, committer or signature data, GitHub signs the commit.

#### The rules in the rulesets

The rule "Require signed commits" lets only signed and verified commits into the branches that it targets ([GitHub: available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)). GitHub tests a merge commit that includes the commits of the head branch. Thus an unsigned commit on a branch can block a squash merge.

Today, the rule targets only `main`. An unsigned commit can thus go into a branch. To correct it, the author must make a new signed commit with a rebase. The author must not force-push, so the author must push to a new branch and open a new PR. The old branch then stays, because agents must not delete a remote branch.

This RFC proposes a second branch ruleset with the target `~ALL`, the value for all branches in the REST API ([GitHub: rules API](https://docs.github.com/en/rest/repos/rules)). It holds "Require signed commits". Then GitHub refuses an unsigned commit when the agent pushes it, and the stale branch cannot occur. The same ruleset can also block force pushes on all branches, as an option. Refer to "Enforcement while the agents use the account of the owner".

#### How the commits get a signature

```mermaid
flowchart LR
    A[Agent commits on the machine of the owner] -->|git config: commit.gpgsign| B[Signed with the key of the owner]
    B --> C[Push the branch]
    C --> D[GitHub verifies: owner account]
    D --> E[Owner squash merges]
    E --> F[GitHub makes a new commit, signed with web-flow]
    F --> G[main: one verified commit for each PR]
```

In text: the agent commits on the machine of the owner. Git signs the commit with the key of the owner. GitHub verifies it against the account of the owner. The owner squash merges, and GitHub signs the new commit on `main` with its `web-flow` key.

Today, agents commit with the Git configuration of the owner. Thus each agent commit has the name, the email and the signature of the owner. GitHub cannot tell an agent commit from an owner commit. The `Co-Authored-By` trailer and the "Agents" section of the PR tell which agent made the change. They are text, not a control.

The owner decided on 2026-11-01 to keep the GPG key of the owner for now. Until the agent identity RFC, Git signs the agent commits with the GPG key of the owner, through the local Git configuration. The rulesets that require signed commits still apply, and each commit on a branch must still have a verified signature.

The known gap: a signature does not tell the commits of the owner from the commits of an agent. "Future possibilities" records this gap.

These facts about local signing are the reasons for the gap. They also apply to a separate agent key, an alternative that the owner did not select:

1. A separate agent key does not stop an agent from signing with the GPG key of the owner. The GPG agent of the owner is available to each process of the owner. Only a human step for each signature on the owner key stops this. A hardware key that needs a touch for each signature gives this step. Examples are an OpenPGP card with a touch policy, or an SSH `-sk` signing key.
2. A passphrase cache is not a step for each signature. After the owner unlocks the key, each process of the owner can sign until the cache expires. In `gpg-agent`, `default-cache-ttl` starts again at each use, so each signature can make the window longer. Only `max-cache-ttl` gives a hard limit. The author did not read the GnuPG documentation for this RFC, so this point is not verified. A short `max-cache-ttl` makes the window smaller, but a window stays.
3. A key that signs with no human step is always unlocked. Each process that runs as the owner can then make a verified commit with it.
4. Persistent verification also has a bad side. A commit that a stolen key signed before its removal stays verified.
5. The committer is still the owner. GitHub and vigilant mode cannot tell one key of the account from another.

Thus a separate agent key is revocable, but it is not an identity. Only the agent identity RFC closes the gap.

#### The merge method

| Method | Signature on `main` | Linear history | Commit title on `main` |
| --- | --- | --- | --- |
| Squash merge | GitHub signs with `web-flow` | Yes | The setting of the repository: today, the commit title when the PR has one commit, else the PR title |
| Rebase merge | GitHub cannot sign. The rule blocks the merge. | Yes | Each commit title of the branch |
| Merge commit | GitHub signs with `web-flow` | No. The ruleset blocks it. | `Merge pull request #N` |

The owner decided on 2026-11-01: the squash merge only, with the PR title and the PR body. On GitHub, this is the squash option "the pull request title and description" ([GitHub: configuring commit squashing](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/configuring-commit-squashing-for-pull-requests)). Then the title on `main` is always the PR title, and a check of the PR title is enough for `main`.

The body on `main` is then the PR description, not the commit messages. The `Co-Authored-By` trailers of the branch commits do not go to `main`. Thus the PR template ends with the trailer lines of the agent, so that `main` keeps them.

### Rulesets and settings

The owner makes these changes. Agents do not change settings or rulesets.

- **Ruleset `main`:**
  - Add "Require status checks to pass" with the check `Run every linter and check` and the PR title check. `AGENTS.md` already tells that this rule exists.
  - Set the source of each required check to the GitHub Actions app (`integration_id`). Without a source, a token with `repo` access can set a commit status with the same name. The rulesets page tells that GitHub then refuses the merge if another person or integration sets the status.
  - Permit only the squash merge in the PR rule.
  - Remove "Require review from Code Owners" after RFC 0003 removes `CODEOWNERS`. Without the file, the rule has no use.
- **New branch ruleset for `~ALL`:** "Require signed commits". As an option, restrict deletions and block force pushes. These two options must exclude `refs/heads/renovate/**`. Renovate force-pushes its branches when it rebases them (`:rebaseStalePrs`), and it deletes the branches of closed PRs.
- **New tag ruleset for `~ALL` tags:** restrict creation, update and deletion, with an empty bypass list. Agents use the account of the owner, so a right of the owner to create tags is also a right of each agent. When the repository makes releases, a release GitHub App goes into the bypass list.
- **Settings:** set the default squash message to "the pull request title and description". Turn off "Allow auto-merge", because an agent could use it to merge a PR without the owner. Only the lock file maintenance PRs of Renovate use it today. When the platform auto-merge is not available, Renovate merges through the API itself, after the checks of the branch ([Renovate: configuration options](https://docs.renovatebot.com/configuration-options/), `platformAutomerge`). This setting does not fix the lock file risk of "The Renovate exception".

The bypass lists stay empty, except for a release App later. Agents use the account of the owner, so each bypass of the owner is also a bypass of each agent.

### Enforcement while the agents use the account of the owner

The `gh` token of the owner has the `repo` scope, and the owner is an administrator of the repository. The REST API needs "Administration: write" to change a ruleset or the settings of a repository ([GitHub: permissions for fine-grained tokens](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens)). A classic `repo` token of an administrator has this permission. The author did not test this. Thus an agent can turn off the ruleset, permit rebase merges or merge a PR. `current_user_can_bypass: never` does not stop a change of the ruleset itself.

These controls do not depend on one agent:

| Control | What it does | Limit |
| --- | --- | --- |
| (a) Separate credentials for the agents | A fine-grained token with "Contents: read", "Pull requests: write" and "Issues: write". Pushes go over SSH with a deploy key or a separate key. To open a PR needs "Pull requests: write". To merge a PR needs "Contents: write". Thus the token can open PRs, but it cannot merge or change settings. | It works only if the agents run as a separate OS user, in a container or in a sandbox. An agent that runs as the owner can read the keyring token of `gh` and use the SSH and GPG agents of the owner. A fine-grained token cannot access the user project "Perso". The board then needs a second classic token with only the `project` scope, which reaches all projects of the owner. Other ways: the owner moves the items, or the agents wait for the installation token of a GitHub App. |
| (b) A plain Git `pre-push` script | It reads each line on its standard input, one line for each reference. It refuses a push to `main`, to `refs/tags/*`, a deletion (a local SHA of zeros) and a non-fast-forward push. A `mise` task installs it in the hooks folder of the repository and chains the existing `pre-push` hook of the Entire CLI. It works for each agent and each Git client. | `git push --no-verify` skips it. |
| (c) Rulesets on `~ALL` branches and tags | GitHub refuses unsigned commits and tags. As an option, it refuses deletions and force pushes on all branches except `renovate/**`. | The token of the owner can change the rulesets. |
| (d) Auto-merge off | No agent can set auto-merge on a PR. | The token of the owner can turn it on again. |

Control (b) does not use the `pre-push` stage of the pre-commit framework. pre-commit 4.7.0 skips the references with a local SHA of zeros, so a deletion never reaches the hook. It also skips the references whose commits are already on the remote, for example a tag on a pushed commit. It gives only the first such reference to the hook. The reviewer of this RFC read this in `pre_commit/commands/hook_impl.py`.

The installation of control (b) follows these rules:

- Do not set `core.hooksPath`. With it, Git stops reading `.git/hooks`. The pre-commit `pre-commit` hook (gitleaks, `detect-private-key`, `no-commit-to-branch`) and the Entire CLI hooks then stop. pre-commit 4.7.0 also refuses to install hooks when `core.hooksPath` has a value. The reviewer of this RFC read this in `install_uninstall.py`.
- Never point a hooks path at a folder in Git. The checked-out branch, for example a Renovate branch, then controls the hook code that runs on the machine.
- The `mise` task writes the script to `$(git rev-parse --git-common-dir)/hooks/pre-push`. First, it moves the Entire CLI hook to a separate name, not `pre-push.legacy`. The script calls the Entire CLI hook with the same arguments and a copy of its input.
- The task must be idempotent. The script has a marker. The task replaces `hooks/pre-push` only when that file has the marker, or when it is the Entire CLI hook. It never moves a file onto an existing side file.
- Do not run `pre-commit install --hook-type pre-push`, with or without `-f`. It moves the script to `pre-push.legacy` or deletes it.
- The Entire CLI can write its hooks again later and remove the chain. The author did not verify this. The test of Rollout step 10 finds this case.

The `commit-msg` hook stays in pre-commit. `.pre-commit-config.yaml` gets `default_install_hook_types: [pre-commit, commit-msg]`. `pre-commit install --hook-type commit-msg` already chains the Entire CLI hook: it moves the existing hook to `commit-msg.legacy`, and it runs that hook first. Do not use `-f` or `--overwrite`, because they delete the legacy hook.

The owner decided on 2026-11-01 to use the recommended controls:

- Now: (b) the plain Git `pre-push` script, (c) the `~ALL` ruleset with signed commits and the tag ruleset, and (d) auto-merge off.
- Later: (a) separate credentials, when the agents run as a separate OS user or in a sandbox. Before that, (a) gives no real protection.

The deletion and force-push rules on all branches stay an option. They need the explicit agreement of the owner, because nobody can then rewrite or delete a branch. If the owner adds them, they exclude `renovate/**`. Agent identity stays out of scope.

### Shared defaults for the personal repositories

The owner wants to use this process in other personal repositories later. The owner decided on 2026-11-01: a public `gsuquet/.github` repository holds all the common files. These are the community health files, the issue forms, `config.yml` and the PR template. [RFC 0003](https://github.com/gsuquet/homelab/pull/168) defines which files stay in each repository, and where.

The owner also asked if `gsuquet/.github` can host the workflows. The facts from the GitHub documentation:

- **Default community health files.** A public `.github` repository can hold defaults for a personal account, not only for an organization ([GitHub: default community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file)).
- **Reusable workflows.** A reusable workflow goes in the `.github/workflows` folder of a repository. A caller uses `{owner}/{repo}/.github/workflows/{filename}@{ref}`, with a commit SHA as the safest `ref` ([GitHub: reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)). The page gives no rule on the name of the repository. A public caller can use a workflow in a public repository ([GitHub: reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations)). Thus `uses: gsuquet/.github/.github/workflows/<file>.yml@<sha>` is possible.
- **Workflow templates.** The pages describe a `workflow-templates` folder in the `.github` repository of an organization only. They tell that "Workflow templates in a public `.github` repository are available to all repository types". They do not tell if a personal account gets them. This RFC does not depend on workflow templates.

GitHub offers three tools to share files:

| Option | What it shares | Updates | Limits |
| --- | --- | --- | --- |
| A `gsuquet/.github` repository (selected) | The community health files, the issue forms, `config.yml` and the PR template. As an option, the reusable workflows. | Each repository sees the current version | The repository must be public. A repository with its own `.github/ISSUE_TEMPLATE/` gets none of the default forms. Labels and rulesets are not part of it. |
| A template repository | All the files of its default branch, one time | None. The new repository has a copy. | The GitHub page tells only about files and branches. |
| Reusable workflows in `gsuquet/workflows` | CI jobs: labeler, PR title check, label sync | Each caller pins a commit SHA, and Renovate updates it | Only workflows |

Sources: [GitHub: default community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) and [GitHub: template repositories](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository).

The only open point is the place of the reusable workflows. Refer to "Unresolved questions".

## Security considerations

- **No identity separates the agents from the owner.** Agents push, open PRs and sign commits as the owner. GitHub cannot enforce the review policy: required reviews and the bypass list treat the agents as the owner. [RFC 0001](0001-records-process.md) ("Security considerations") named agent identity as a subject for RFC 0002. On 2026-10-31, the owner moved it out of RFC 0002 to a later RFC.
- **The token of the owner can change the controls.** The `gh` token of the owner has the `repo` scope, and the owner is an administrator. An agent that uses this token can change or turn off a ruleset, permit rebase merges, turn on auto-merge or merge a PR. The rulesets protect against a mistake, not against an agent that ignores the rules. "Enforcement while the agents use the account of the owner" gives the controls that make this risk smaller.
- **The signing keys of the owner are available to the agents.** Each agent runs as the user of the owner, so it can use the GPG agent of the owner. A signature proves that a process on the machine of the owner made the commit. It does not prove that the owner read it. The owner decided to keep the GPG key of the owner for the agent commits, until the agent identity RFC. Thus a signature does not tell the commits of the owner from the commits of an agent. A commit that a stolen key signed stays verified after the removal of the key. Only a human step for each signature stops an agent from signing as the owner, for example a hardware key touch.
- **A required status check can come from a false source.** A token with `repo` access can set a commit status with the name of a required check. The rulesets set the source of each required check to the GitHub Actions app.
- **The issues and the milestones are public.** The repository is public. The project "Perso" is private, but an issue on the board stays public. An issue, a milestone or a project field must not contain secrets, private addresses or the details of a weakness that is not corrected yet. Use the private vulnerability report form. The `config.yml` of the issue forms links to it.
- **A token with the `project` scope can change all the projects of the owner.** The board holds only plans, not code, so the risk is small.
- **A label workflow needs write access.** The labeler and a label sync need `pull-requests: write` or `issues: write`. They run with `pull_request`, not `pull_request_target`, so a fork PR gets no write token. Each action stays pinned to a commit SHA.
- **Renovate merges without the owner.** Today, it merges the dev tool PRs after the checks of the branch pass. A compromised dev tool can thus reach `main`. The lock file maintenance PRs use the auto-merge of GitHub, and `main` has no required check. Thus they can merge with no passing check, and they can change the provider and chart lock files that reach the instances. This risk exists today. The orchestrator proposes a separate fix to the owner. The `minimumReleaseAge` of three days makes the risk smaller, but vulnerability PRs skip it. "The Renovate exception" limits these merges, and Rollout step 10 checks them.

## Rollout

```mermaid
flowchart TD
    A[Step 1: Merge RFC 0002] --> B[Step 2: ADRs from RFC 0002]
    B --> C[Step 3: Labels file and sync]
    C --> D[Step 4: Issue forms, PR template, labeler]
    B --> E[Step 5: Rulesets and settings]
    B --> F[Step 6: Projects board]
    F --> G[Step 7: Milestones with the owner]
    D --> H[Step 8: Move the Claude Docs plans to issues]
    G --> H
    H --> I[Step 9: Owner deletes the Claude Docs plans]
    E --> J[Step 10: Checks]
    D --> J
```

In text: after the merge of this RFC, the ADRs come first. Then three lines of work run in parallel: labels and templates, rulesets and settings, and the board with its milestones. The move of the Claude Docs plans waits for the templates and the milestones. The owner deletes the plans after the move. The checks come last.

1. The owner accepts this RFC and merges its PR.
2. An author derives the ADRs. Possible ADRs:
   - "Track work in a GitHub Project with issues and milestones".
   - "Use the order of work from RFC to code".
   - "Use atomic PRs and the review loop". It changes the exit of the review loop of ADR 0005 (flow step 3). ADR 0005 has no partial supersede. Thus this ADR restates all of ADR 0005 with the new exit, and it supersedes ADR 0005 in full.
   - "Use the label taxonomy".
   - "Require signed commits and squash merges".
   - "Enforce the rules with Git hooks, CI checks, policies and rulesets".
3. An author adds `.github/labels.yml` and its sync. The owner runs the sync, because it changes the labels of the repository.
4. An author adds the issue forms, `config.yml`, the new PR template and the new `.github/labeler.yml`.
5. The owner changes the rulesets and the settings, as "Rulesets and settings" tells. The token of the agents can do this, but the rules of this RFC do not let an agent do it.
6. The owner or an agent, with the approval of the owner, puts the target fields, states and views into the project "Perso". The `gh` token has the `project` scope, so an agent can use `gh project field-create`. The owner turns on the built-in workflows and makes the views in the web interface, because `gh` cannot change them.
7. The owner and an author make the list of milestones, with their acceptance criteria.
8. An agent moves the content of the Claude Docs plans into issues, sub-issues and milestones on the board. The plans are "Homelab implementation plan", the OpenChoreo plan and the promotion proposal. The owner reads the result.
9. The owner deletes the Claude Docs plans. After this step, the board is the only source of plans.
10. An author adds the checks, as rule 8 of `AGENTS.md` requires:
    - A PR title check in CI, for example `commitlint` on the PR title. It becomes a required status check. `config-conventional` limits the header to 100 characters. Renovate titles can be longer, so the check or the Renovate `commitMessage` options must agree before the check becomes required.
    - The `pre-push` script of control (b), with its `mise` task, and `default_install_hook_types` in `.pre-commit-config.yaml`. A test pushes each refused reference type to a local bare repository, and checks the refusal. Verify in the implementation PR:
      - The test runs the `mise` task two times. Then it checks that the two hooks are present, and that each one runs one time.
      - The Entire CLI `pre-push` and `commit-msg` hooks still run after the installation.
    - A Conftest policy on `renovate.json`. It permits `automerge: true` only in two places. The first is the dev tool rule, with its fixed files, managers and update types. The second is one `packageRules` entry for `lockFileMaintenance` with `matchManagers: ["mise"]` and its own `branchTopic`. It requires `lockFileMaintenance.automerge: false` at the top level.
    - A scheduled check that lists the PRs that `app/renovate-gsuquet` merged. It fails when a merged PR changed a file outside of the files of the exception.
    - A check, after the `~ALL` ruleset exists, that GitHub can still delete the head branch after a merge. The GitHub pages do not tell if a deletion rule blocks this.
    - A check that `.github/labels.yml` is valid against a schema, in `schemas:check`.
    - A check that each issue form is valid YAML with the required keys, in `schemas:check`.
    - A check of the rulesets and the settings: a script compares `gh api repos/gsuquet/homelab/rulesets` and the merge settings with a file in Git. It needs the network, so it runs on a schedule, not in `mise run lint`.
    - A test that a Renovate dev tool PR can still merge with the rule "Require review from Code Owners". This test applies until the owner removes the rule. The rule did not block the owner PRs, but the author has no proof for a PR of the App.
    - The `required_signatures` rules stay the check of signed commits.

To go back, the owner reverts the PRs of steps 3, 4 and 10, and restores the rulesets from the file of step 10. The board and the issues can stay: they do not change the code.

## Drawbacks

- The owner must create and maintain a project, milestones and labels. This is more work than a document.
- The board shows the state only if each agent moves its items. An agent that forgets leaves a wrong state.
- A new reviewing agent for each round costs more time and more tokens than one reviewer.
- The order of work makes small changes slower. A small feature needs an RFC, an ADR and documentation before the code.
- The squash merge loses the commits of the branch on `main`. The PR keeps them.
- Signed commits with the key of the owner give a false sense of control. The signature does not show which agent made the commit.
- While the agents use the token of the owner, the rulesets stop mistakes, not a rogue agent.

## Rationale and alternatives

- **Keep the plans in Claude Docs.** Agents in the repository cannot read them with `gh`, PRs cannot close them, and they are outside of the history of the repository.
- **Issues and milestones without a project.** Milestones show progress, but not the state of each item, and not the queue of the owner.
- **Plans as Markdown files in the repository.** Each change of state needs a PR. GitHub cannot link a file to a PR or close it.
- **Priority and state as labels only.** Labels are flat. A project field has fixed values and a sort order. This RFC keeps labels for the facts that tools and filters outside of the project need.
- **Labels without a prefix.** The GitHub defaults do this. With more than ten labels, the reader cannot see which labels go together.
- **Rebase merge.** GitHub cannot sign the rebased commits, and the rule "Require signed commits" then blocks the merge.
- **No signed commits.** The owner chose to require them. They also make sure that each commit on a branch comes from a key on the account of the owner.
- **Code first, documentation after.** The documentation then follows the code and not the decision. A reviewer cannot compare the code with a target.
- **Agent hooks as the controls.** Each agent has its own hook format, and a local LLM can have none. Git hooks, CI checks, policies and rulesets apply to each agent.

The owner answered the open questions of this RFC on 2026-11-01, in a comment on PR #167. These alternatives were not selected:

- **Milestones.** One milestone for each wave of RFCs, or one for each RFC. A wave is a plan of the order of work, and an RFC alone is not measurable.
- **Board.** A new user-level project, or one project for each repository. A new project duplicates "Perso". One project for each repository makes many boards to look at, and each new repository needs a copy of the fields and the views.
- **Priority.** `priority/` labels, or labels and a field. Two sources can disagree.
- **Label sync.** A reusable workflow now, or changes by hand. A workflow needs `issues: write` in CI. The owner keeps it for later.
- **Signing key.** A separate SSH signing key for the agents, with a hardware owner key that needs a touch for each signature. Or commits through the GitHub API, which needs an agent identity. The owner keeps the GPG key for now.
- **Squash body.** The commit messages of the branch, or only the PR title. The owner selected the PR title and description.
- **Shared files.** A template repository, or a copy in each repository. A template repository copies the files one time and does not update the old repositories.
- **Reviewer.** The same reviewing agent for all the rounds of one PR. A new agent does not trust its earlier review.
- **Board automation.** A GitHub Actions workflow that moves the items on PR events. It needs a new secret with write access to all the projects of the owner.
- **Record `issue` field.** A new field in the front matter changes the metadata of [ADR 0004](../adrs/0004-use-yaml-front-matter-for-record-metadata.md), and the PR already links the issue.
- **Enforcement.** Separate agent credentials now. They give no real protection while the agents run as the user of the owner.

## Prior art

- **Rust RFC process.** The [rust-lang/rfcs README](https://github.com/rust-lang/rfcs) tells that each accepted RFC gets a tracking issue for its implementation. Each RFC PR gets the label of the most relevant team. This RFC uses milestones and issues for the same purpose.
- **Kubernetes labels.** The [Kubernetes guide for approvers and reviewers](https://kubernetes.io/docs/contribute/review/for-approvers/) uses labels with a prefix: `priority/`, `triage/`, `lifecycle/`, `language/`, `do-not-merge/` and `kind/`, for example `kind/support`. Bots set many of them from commands in comments. The author found no `area/` label on kubernetes.io. The Kubernetes label list is on GitHub, outside of the sources that the author read. This RFC takes the format `<prefix>/<name>`, but with fewer prefixes, and tools set them from files and branch names.
- **GitHub Projects.** The [Projects documentation](https://docs.github.com/en/issues/planning-and-tracking-with-projects/learning-about-projects/about-projects) gives the layouts, the fields and the limits. The [built-in automations](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations) set the state only for some events.
- **GitHub milestones and sub-issues.** [Milestones](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/about-milestones) show the progress of a group of issues and PRs. [Sub-issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues) split a task into parts.
- **Closing keywords.** [Linking a PR to an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue) tells that `Closes #N` works only when the PR goes into the default branch.
- **Conventional Commits.** [The specification 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) gives the format of the commit messages. The author did not read this page for this RFC. The `commitlint` hook of this repository uses the `config-conventional` rules.
- **Renovate.** Renovate uses semantic commit prefixes when `semanticCommits` is on, and it makes the titles lowercase by default ([Renovate configuration options](https://docs.renovatebot.com/configuration-options/)). Its PR titles thus pass a Conventional Commits check, except for the length.
- **Signature verification on GitHub.** The pages about [signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification), [the signing key in Git](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key) and [rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) give the facts in "Signed commits".
- **Token permissions.** [Permissions for fine-grained tokens](https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens) gives the permission of each REST endpoint. The [rules API](https://docs.github.com/en/rest/repos/rules) gives the `~ALL` target and the `integration_id` of a required check.
- **Issue forms and shared defaults.** [Issue form syntax](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms), [issue template configuration](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository) and [default community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file).
- **Reusable workflows and workflow templates.** [Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows), [reusing workflow configurations](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations) and [create workflow templates](https://docs.github.com/en/actions/how-tos/reuse-automations/create-workflow-templates) give the facts in "Shared defaults for the personal repositories".

## Unresolved questions

The owner answered the eleven questions of the review on 2026-11-01, in a comment on PR #167. The body of this RFC states each decision. "Rationale and alternatives" lists the options that the owner did not select.

One point stays open:

1. **One repository or two for the shared files?** The owner asked if `gsuquet/.github` can also host the workflows. The GitHub documentation permits it. Refer to "Shared defaults for the personal repositories". Options:
   - (a) `gsuquet/.github` alone. It holds the common files and the reusable workflows. A later PR moves the workflows from `gsuquet/workflows`, and each caller changes its `uses:` line.
   - (b) `gsuquet/.github` for the common files, and `gsuquet/workflows` for the reusable workflows, as today.

   Recommendation: (a). One repository is one source to read, to pin and to update. The move can wait until a second repository uses the process. Until then, the callers keep `gsuquet/workflows`.

## Future possibilities

- **Agent identity.** A later RFC gives the agents their own identity, for example a GitHub App or a bot account. Then GitHub can tell the agents from the owner, required reviews can work, and the bypass lists can exclude the agents. GitHub can sign the commits of the App.
- **The signing gap.** Until the agent identity RFC, the agents sign with the GPG key of the owner. Thus a signature does not tell the commits of the owner from the commits of an agent. The agent identity RFC closes this gap. A separate agent key with a hardware owner key is a smaller step, if the owner wants one before.
- **The repository structure and the community health files.** RFC 0003 defines which files stay in each repository. The shared files go in `gsuquet/.github`.
- **The Kubernetes labels and annotations.** RFC 0004 defines them. They are a different subject from the GitHub labels of this RFC.
- **The agents RFC.** A later RFC implements the roles and the review loop of this RFC in a form that does not depend on one agent. Each agent, for example Claude Code, Antigravity or a local LLM, gets an adapter: skills, subagents or hooks in the format of that agent. The Git hooks, CI checks, policies and rulesets of this RFC stay the controls. That RFC also removes the rules that this RFC replaces from `AGENTS.md`.
- **A merge queue.** When many PRs wait at the same time, a merge queue can test each one against the latest `main`.
- **Iterations.** A project iteration field can group the work in fixed periods, if the owner wants a schedule.
- **Project insights.** Charts of the board can show the progress of each milestone.
