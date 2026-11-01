# RFCs

A request for comments (RFC) proposes a change before somebody does the work. [RFC 0001](0001-records-process.md) defines the process.

## Write an RFC

1. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md`. Use the next free number.
2. Write each section of the template.
3. Add a row for the RFC to the table on this page.
4. Open a GitHub draft PR. Put its number in the `pr` field.
5. Ask a reviewer, a person or an agent that is not the author, to review the RFC. Correct it until the reviewer finds no problem.
6. Run `mise run lint`.
7. Set the status to `review`, and mark the PR as ready for review.

These steps follow the flow that RFC 0001 proposes.

## List

| RFC | Title | Status |
| --- | --- | --- |
| [0001](0001-records-process.md) | Records process | `accepted` |
| [0005](0005-repository-scope-and-naming.md) | Repository scope and naming | `review` |

## Source of the template

The template is an adaptation of the [Rust RFC template](https://github.com/rust-lang/rfcs/blob/master/0000-template.md). Its license is not confirmed, and the owner accepts this risk: refer to "Licenses" in [RFC 0001](0001-records-process.md#licenses).
