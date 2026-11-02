---
adr: "0009"
status: accepted
date: 2026-11-02
rfc: "0002"
supersedes: []
superseded-by: null
---

# ADR 0009: Use atomic PRs that close one issue

The diagram shows the link between the work items and a PR. In text: one issue, or one sub-issue, gives one PR. The PR has `Closes #N` in its description. When the PR merges into `main`, GitHub closes the issue.

```mermaid
flowchart LR
    I[Issue or sub-issue: one task] --> P[Atomic PR: Closes #N]
    P -->|passes mise run lint alone| R[Review loop]
    R -->|owner squash merges into main| C[GitHub closes the issue]
```

## Context and problem statement

A PR with more than one subject is hard to review. A reviewer cannot give one decision about it, and a revert removes more than one change. A PR that needs a later PR to pass the checks leaves `main` broken between the two merges. What is the size and the scope of a PR?

[RFC 0002](../rfcs/0002-how-we-work.md) ("The work items", "Atomic PRs") has the full discussion.

## Considered options

- No rule on the size and the scope of a PR.
- Atomic PRs: one task, one issue, one subject.

RFC 0002 names no other option.

## Decision outcome

Chosen option: "Atomic PRs: one task, one issue, one subject". A reviewer can give one decision about each PR, and the board of [ADR 0007](0007-track-work-in-the-perso-github-project.md) can link each task to its PR.

An atomic PR has these properties (RFC 0002, "Atomic PRs"):

- It closes one issue, or one sub-issue, with `Closes #N` in its description. GitHub closes the issue when the PR merges into the default branch.
- A record has no `issue` field in its front matter. The PR of the record closes the issue (owner, 2026-11-01). A new field would change the metadata of [ADR 0004](0004-use-yaml-front-matter-for-record-metadata.md), and the PR already links the issue.
- It has one subject. A reviewer can give one decision about it: merge or change.
- It passes `mise run lint` alone. It does not need a later PR to pass the checks.
- It does not mix a refactoring with a change of behavior.
- An RFC PR holds only the RFC and its index row. An ADR PR holds the ADRs, their index rows and, as [ADR 0022](0022-use-rfcs-and-adrs-to-record-decisions-without-codeowners.md) permits, implementation commits.
- A PR after the ADR step links to its ADRs.
- A PR can have more than one commit. The squash merge of [ADR 0014](0014-require-signed-commits-squash-merges-and-conventional-commits.md) makes one commit on `main` from them.

### Consequences

- Good, because each PR gets one decision, and a revert removes one change.
- Good, because `main` passes the checks after each merge.
- Good, because the issue closes when its PR merges, so the board stays correct.
- Bad, because a large task needs more PRs, and the owner must review more PRs.

### Confirmation

`mise run lint` runs in CI on each PR. The ruleset of `main` makes it a required check ([ADR 0015](0015-enforce-the-rules-with-git-hooks-ci-checks-policies-and-rulesets.md)).

The reviewer checks these points:

- The PR description has `Closes #N` for one issue.
- The PR has one subject, and it does not mix a refactoring with a change of behavior.
- An RFC PR holds only the RFC and its index row.
