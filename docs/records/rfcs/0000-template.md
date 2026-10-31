---
# Copy this file to NNNN-short-title.md. Refer to docs/records/rfcs/index.md.
rfc: "NNNN"
status: draft # draft | review | accepted | rejected | withdrawn
start-date: YYYY-MM-DD
pr: null # The number of the PR that holds this RFC.
---

# RFC NNNN: Short title

Include a diagram when the text describes a flow, a state, a structure or an interaction. Use a fenced code block with the language `mermaid`, and add a short text version below it.

## Summary

Write one paragraph that tells what this RFC changes.

## Motivation

Tell which problem this RFC solves. Give the background that a reader must know.

Give specific use cases. For each use case, tell how the change helps. The design uses these use cases.

This section is one of the most important sections of an RFC. It can be long.

## Proposal

Explain the proposal as if it is already part of the repository, and you teach it to a new contributor. Usually, this means:

- Give a name to each new concept, and explain it.
- Use examples to explain the change.
- Tell how a contributor must think about the change, and how it changes their work. Be as specific as possible.
- If applicable, show examples of error messages, warnings or migration steps.
- Tell how the change affects the work to read, understand and maintain the repository.

For a process RFC, use examples to introduce the process, and tell what changes for each person or agent.

## Detailed design

This section is the technical part of the RFC. Explain the design with enough detail to show:

- How it interacts with the modules, the instances, the tools and the other records.
- How to implement it.
- What occurs in the special cases. Use an example for each special case.

Go back to the examples of the "Proposal" section, and explain how the design makes them work.

## Security considerations

Tell how the change affects the security of the homelab, the repository and the supply chain. For example:

- Which new data, secrets or credentials the change uses, and where they go.
- Which new network paths, permissions or trust relations the change adds.
- Which threats the change prevents, and which new threats it adds.

If the change has no effect on security, write this and tell why.

Do not write secrets or other sensitive data in an RFC. The repository is public.

## Rollout

Tell how the change goes from this RFC into the repository. For example:

- The order of the PRs, and the ADRs that come from this RFC.
- The checks (schema, policy or linter) that enforce the new rules.
- The migration of the existing code and documentation.
- How to go back to the old state if the change fails.

## Drawbacks

Tell why the repository must not do this.

## Rationale and alternatives

- Why is this design the best design?
- Which other designs did you examine, and why did you not select them?
- What occurs if the repository does not do this?

## Prior art

Discuss prior art, both the good and the bad parts, that relates to this proposal. For example:

- Other projects or communities that solve the same problem, and what they learned.
- Papers, specifications or articles about the problem.

Give a URL for each source.

Prior art helps you to learn from other projects, and it gives the reader a full view. If there is no prior art, write this. Prior art alone is not a reason to accept an RFC.

## Unresolved questions

- Which parts of the design do you expect to resolve through the review of this RFC, before acceptance?
- Which parts of the design do you expect to resolve during the implementation?
- Which related problems are out of the scope of this RFC? Another RFC can solve them later.

## Future possibilities

Tell how this proposal can change in the future, and how these changes affect the repository. Use this section to examine all the possible interactions with the repository.

You can also write ideas here that relate to the proposal but are out of its scope.

If you cannot think of a future possibility, write this.

A note in this section is not a reason to accept this RFC or a future RFC. Put the reasons in the "Motivation" or the "Rationale and alternatives" section.

<!--
This template is an adaptation of the Rust RFC template:
https://github.com/rust-lang/rfcs/blob/f17e8623ee2e2854570dcdb936a9f4ab08c0fcd4/0000-template.md
License: the rust-lang/rfcs README states that the repository is being
relicensed under the MIT license or the Apache License 2.0, and that some parts
already are: https://github.com/rust-lang/rfcs#license
The license status of 0000-template.md could not be confirmed. Refer to the
unresolved questions of RFC 0001. Changes: the "Guide-level
explanation" section is now "Proposal", the "Reference-level explanation"
section is now "Detailed design", the "Security considerations" and "Rollout"
sections are new, the header list is now YAML front matter, and the text uses
ASD-STE100.
-->
