# Records

This section holds the decision records of the repository. It is outside of the four Diátaxis sections, because a record is a fixed document with a date and a status.

| Record type | Content |
| --- | --- |
| [RFCs](rfcs/index.md) | A request for comments (RFC) proposes a change, and its PR holds the discussion. |
| [ADRs](adrs/index.md) | An architecture decision record (ADR) records one decision from an accepted RFC. |

[RFC 0001](rfcs/0001-records-process.md) defines the process: when to write a record, the flow, the states and the templates.

The short flow:

1. Refine the subject.
2. Write the RFC. A different agent reviews it, until it is correct.
3. The owner reviews the RFC PR. The author answers each comment.
4. The owner approves the PR. This approval accepts the RFC.
5. Agents derive one or more ADRs from the RFC. The owner approves them.
6. The implementation starts.

Only the owner accepts an RFC or an ADR.
