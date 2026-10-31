---
# Copy this file to NNNN-short-title.md. Refer to docs/records/adrs/index.md.
adr: "NNNN"
status: proposed # proposed | accepted | superseded | deprecated
date: YYYY-MM-DD # The date of the last change of the status.
rfc: "NNNN" # The number of the accepted RFC that this decision comes from.
supersedes: [] # The numbers of the ADRs that this ADR replaces, for example ["0004"].
superseded-by: null # The number of the ADR that replaces this ADR.
---

# ADR NNNN: Short title of the problem and the solution

Include a diagram when the text describes a flow, a state, a structure or an interaction. Use a fenced code block with the language `mermaid`, or an SVG file. Add a short text version next to it, above or below.

## Context and problem statement

Tell the context and the problem in two or three sentences, or as a short story. You can write the problem as a question.

Link to the RFC that this decision comes from. Do not copy the discussion of the RFC here.

## Considered options

- Title of option 1
- Title of option 2
- Title of option 3

## Decision outcome

Chosen option: "Title of option 1", because {justification}. For example, it is the only option that meets a mandatory criterion, or it is the best option in the comparison of the RFC.

### Consequences

- Good, because a positive consequence, for example a better quality of the system.
- Bad, because a negative consequence, for example a new cost or a new risk.

### Confirmation

Tell how to make sure that the implementation agrees with this decision. Prefer an automatic check: a schema, a policy, a linter or a test. Give its name and where it runs. If only a review can check the decision, tell what the reviewer must look at.

<!--
This template is an adaptation of the minimal MADR 4.0.0 template:
https://github.com/adr/madr/blob/2475fe1973f66a12aaf58a91d8fa7b42c0f5ea3d/template/adr-template-minimal.md
MADR has the license "MIT OR CC0-1.0":
https://github.com/adr/madr/blob/main/LICENSE
This repository uses it under CC0-1.0. Changes: the YAML front matter
comes from the full MADR template and has the "adr", "rfc", "supersedes" and
"superseded-by" fields instead of "decision-makers", "consulted" and
"informed". The "Confirmation" section comes from the full MADR template. The
"Consequences" section is mandatory. The text uses ASD-STE100. RFC 0001 gives
the reasons.
-->
