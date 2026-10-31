---
adr: "0001"
status: proposed
date: 2026-10-31
rfc: "0001"
supersedes: []
superseded-by: null
---

# ADR 0001: Use RFCs and ADRs to record decisions

The diagram shows the two record types. In text: an RFC is a proposal. If the owner accepts it, the author derives one or more ADRs from it. The owner decides on each ADR. An ADR PR can hold implementation commits before that decision. The merge of the owner records each outcome, also a refusal. A rejected RFC or ADR stays in the repository.

```mermaid
flowchart LR
    RFC[RFC: proposal and discussion] -->|owner accepts, merge records it| ADR[ADR: one decision]
    ADR -->|owner accepts, merge records it| IMP[Later implementation PRs]
    RFC -->|rejected or withdrawn, merge records it| END[No ADR. The RFC stays.]
    ADR -->|rejected, merge records it| REJ[No code. The ADR stays.]
```

## Context and problem statement

The repository has no single record of its decisions. Some are in `AGENTS.md` or in explanation pages. Others are only in the PR history. Agents do most of the work, and an author that cannot find a decision can change it by accident. How does the repository record its decisions?

[RFC 0001](../rfcs/0001-records-process.md) ("Motivation", "Proposal") has the full discussion.

## Considered options

- Only ADRs, without RFCs.
- Only RFCs, without ADRs.
- Issues or GitHub Discussions for the RFCs.
- The records in `docs/explanation/`.
- RFCs and ADRs, in `docs/records/`.

## Decision outcome

Chosen option: "RFCs and ADRs, in `docs/records/`". It is the only option that gives both the full discussion before a decision and a short record of the decision after it. The text stays in Git, where Vale checks it and the comments are next to the lines. RFC 0001 ("Rationale and alternatives") rejects each other option:

- Only ADRs: they hold no long discussion.
- Only RFCs: a reader who wants one decision must read a long RFC.
- Issues or Discussions: the text is outside of the repository.
- `docs/explanation/`: an explanation page changes with the system. A record does not change after acceptance.

The rules of this decision (RFC 0001, "Proposal" and "Detailed design"):

- An RFC is a proposal and its discussion. An ADR is one decision. An ADR always comes from an accepted RFC, and one RFC can give many ADRs.
- The records are in `docs/records/`, outside of the Diátaxis sections, because a record is a fixed document with a date and a status.
- Write an RFC for each change, except a plain bug fix. A plain bug fix makes the code do what its documentation, its tests or its PR already tell, and it adds no new behavior. Examples: a correction of a typing error, a broken link, or a wrong value in a template.
- An ADR is never in the same PR as its RFC. An ADR PR can also hold implementation commits before the owner decides. If the owner refuses the ADR, the author removes them before setting `rejected`.
- Only the owner accepts an RFC or an ADR. The owner merges the PR, and the merge records the outcome: `accepted`, `rejected` or `withdrawn`. The repository keeps all records, whatever their outcome. Agents never merge a PR.
- No earlier decision stays in force on its own authority. Each one must come back through an RFC (ADR 0005 gives the details).

The flow, the states, the numbering and the diagram rule are in ADR 0005 and ADR 0006.

### Consequences

- Good, because each decision has one short record with its reasons, and a link to the full discussion.
- Good, because the history stays complete. A rejected record stays, and a new ADR replaces an old one.
- Bad, because each change takes more time. It needs an RFC, then an ADR, before the code.
- Bad, because the owner must review more PRs.
- Bad, because the RFC and the ADR can repeat a part of the same content.
- Bad, because the indexes need a manual update until the check exists.

### Confirmation

RFC 0001 ("Rollout", step 4) plans these checks as future work. They are not part of this ADR:

- A check that the `rfc` field of each ADR points to an accepted RFC.
- A check that each index lists each record with the correct status.
- Possibly, "Require conversation resolution before merging" in the ruleset of `main`.

Until these checks exist, the reviewer checks that each ADR comes from an accepted RFC, is not in the PR of its RFC, and has a row in the index. `.github/CODEOWNERS` gives `docs/records/` to the owner.
