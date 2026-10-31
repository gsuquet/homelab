# RFCs

A request for comments (RFC) proposes a change before somebody does the work. [RFC 0001](0001-records-process.md) defines the process.

## Write an RFC

1. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md`. Use the next free number.
2. Write each section of the template.
3. Add a row for the RFC to the table on this page.
4. Ask a different agent to review the RFC. Correct it until the reviewer finds no problem.
5. Run `mise run lint`.
6. Set the status to `review`, and open a PR.

## List

| RFC | Title | Status |
| --- | --- | --- |
| [0001](0001-records-process.md) | Records process | `review` |

## Source of the template

The template is an adaptation of the [Rust RFC template](https://github.com/rust-lang/rfcs/blob/master/0000-template.md). The [rust-lang/rfcs](https://github.com/rust-lang/rfcs#license) repository licenses it under the MIT license or the Apache License 2.0. This repository uses it under the MIT license.
