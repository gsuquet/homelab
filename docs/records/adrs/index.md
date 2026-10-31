# ADRs

An architecture decision record (ADR) records one decision. Each ADR comes from an accepted [RFC](../rfcs/index.md). [RFC 0001](../rfcs/0001-records-process.md) defines the process.

## Write an ADR

1. Make sure that the RFC has the status `accepted`.
2. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md`. Use the next free number.
3. Write each section of the template. Put the RFC number in the `rfc` field.
4. Add a row for the ADR to the table on this page.
5. Ask a reviewer, a person or an agent that is not the author, to review the ADR. Correct it until the reviewer finds no problem.
6. Run `mise run lint`, and open a PR. The PR must not hold the RFC. It can also hold the implementation.
7. When the owner asks, set the status to `accepted` or `rejected`, and update the row on this page. The owner merges the PR in both cases.

The repository keeps all ADRs, also the ADRs with the status `rejected`.

## List

| ADR | Title | RFC | Status |
| --- | --- | --- | --- |

There are no ADRs yet.

## Source of the template

The template is an adaptation of the minimal template of [MADR](https://adr.github.io/madr/) 4.0.0. MADR has the license `MIT OR CC0-1.0` ([LICENSE](https://github.com/adr/madr/blob/main/LICENSE)). This repository uses it under CC0-1.0.
