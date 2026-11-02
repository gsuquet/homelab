# ADRs

An architecture decision record (ADR) records one decision. Each ADR comes from an accepted [RFC](../rfcs/index.md). [RFC 0001](../rfcs/0001-records-process.md) defines the process.

## Write an ADR

1. Make sure that the RFC has the status `accepted`.
2. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md`. Use the next free number.
3. Write each section of the template. Put the RFC number in the `rfc` field.
4. Add a row for the ADR to the table on this page.
5. Run the review loop of [ADR 0010](0010-use-the-record-lifecycle-the-review-loop-and-the-roles.md): a new reviewing agent for each round, until no finding stays open.
6. Run `mise run lint`, and open a PR. The PR must not hold the RFC. Before the owner decides, it can also hold implementation commits.
7. When the owner asks, set the status to `accepted` or `rejected`, and update the row on this page. For `rejected`, first remove the implementation commits. The owner merges the PR in both cases.

The repository keeps all ADRs, also the ADRs with the status `rejected`.

## List

| ADR | Title | RFC | Status |
| --- | --- | --- | --- |
| [0001](0001-use-rfcs-and-adrs-to-record-decisions.md) | Use RFCs and ADRs to record decisions | [0001](../rfcs/0001-records-process.md) | `superseded` |
| [0002](0002-use-the-adapted-rust-rfc-template.md) | Use the adapted Rust RFC template | [0001](../rfcs/0001-records-process.md) | `accepted` |
| [0003](0003-use-the-trimmed-madr-template.md) | Use the trimmed MADR template | [0001](../rfcs/0001-records-process.md) | `accepted` |
| [0004](0004-use-yaml-front-matter-for-record-metadata.md) | Use YAML front matter for record metadata | [0001](../rfcs/0001-records-process.md) | `accepted` |
| [0005](0005-use-the-rfc-and-adr-lifecycle-and-flow.md) | Use the RFC and ADR lifecycle and flow | [0001](../rfcs/0001-records-process.md) | `superseded` |
| [0006](0006-number-records-in-separate-sequences.md) | Number records in separate sequences | [0001](../rfcs/0001-records-process.md) | `accepted` |
| [0007](0007-track-work-in-the-perso-github-project.md) | Track work in the "Perso" GitHub Project with issues and milestones | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0008](0008-use-the-order-of-work-from-rfc-to-code.md) | Use the order of work from RFC to code | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0009](0009-use-atomic-prs-that-close-one-issue.md) | Use atomic PRs that close one issue | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0010](0010-use-the-record-lifecycle-the-review-loop-and-the-roles.md) | Use the record lifecycle, the review loop and the roles | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0011](0011-limit-renovate-automerge-to-dev-tool-prs-and-the-mise-lock-file.md) | Limit Renovate automerge to dev tool PRs and the mise lock file | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0012](0012-use-the-label-taxonomy-the-issue-forms-and-the-pr-template.md) | Use the label taxonomy, the issue forms and the PR template | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0013](0013-share-community-defaults-and-reusable-workflows-in-gsuquet-github.md) | Share community defaults and reusable workflows in `gsuquet/.github` | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0014](0014-require-signed-commits-squash-merges-and-conventional-commits.md) | Require signed commits, squash merges and Conventional Commits | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0015](0015-enforce-the-rules-with-git-hooks-ci-checks-policies-and-rulesets.md) | Enforce the rules with Git hooks, CI checks, policies and rulesets | [0002](../rfcs/0002-how-we-work.md) | `accepted` |
| [0016](0016-use-the-target-repository-structure.md) | Use the target repository structure | [0003](../rfcs/0003-repository-structure.md) | `accepted` |
| [0017](0017-use-the-terraform-module-and-instance-layout.md) | Use the Terraform module and instance layout | [0003](../rfcs/0003-repository-structure.md) | `accepted` |
| [0018](0018-use-the-gitops-layout-by-cluster-and-a-rendered-app-of-apps.md) | Use the GitOps layout by cluster and a rendered App of Apps | [0003](../rfcs/0003-repository-structure.md) | `accepted` |
| [0019](0019-use-the-naming-rules.md) | Use the naming rules | [0003](../rfcs/0003-repository-structure.md) | `accepted` |
| [0020](0020-keep-the-legacy-folders-deprecated-until-the-raspberry-pi-migration.md) | Keep the legacy folders deprecated until the Raspberry Pi migration | [0003](../rfcs/0003-repository-structure.md) | `accepted` |
| [0021](0021-use-the-community-health-files-and-the-mit-license.md) | Use the community health files and the MIT license | [0003](../rfcs/0003-repository-structure.md) | `accepted` |
| [0022](0022-use-rfcs-and-adrs-to-record-decisions-without-codeowners.md) | Use RFCs and ADRs to record decisions, without CODEOWNERS | [0003](../rfcs/0003-repository-structure.md) | `accepted` |
| [0023](0023-use-the-custom-prefix-subgroup-infra-gsuquet-com.md) | Use the custom prefix `<subgroup>.infra.gsuquet.com` | [0004](../rfcs/0004-labels-and-annotations.md) | `accepted` |
| [0024](0024-use-the-families-of-keys-and-forbid-keys-without-a-prefix.md) | Use the families of keys, and forbid keys without a prefix | [0004](../rfcs/0004-labels-and-annotations.md) | `accepted` |
| [0025](0025-use-six-sub-groups-for-the-keys-of-the-repository.md) | Use six sub-groups for the keys of the repository | [0004](../rfcs/0004-labels-and-annotations.md) | `accepted` |
| [0026](0026-require-the-keys-of-the-reference-table.md) | Require the keys of the reference table on namespaces, charts and cloud resources | [0004](../rfcs/0004-labels-and-annotations.md) | `accepted` |
| [0027](0027-use-the-annotation-tracking-method-of-argo-cd.md) | Use the annotation tracking method of Argo CD | [0004](../rfcs/0004-labels-and-annotations.md) | `accepted` |
| [0028](0028-map-kubernetes-keys-to-cloud-labels-and-tags-with-one-rule.md) | Map Kubernetes keys to cloud labels and tags with one rule | [0004](../rfcs/0004-labels-and-annotations.md) | `accepted` |
| [0029](0029-enforce-the-key-rules-with-conftest-checks.md) | Enforce the key rules with Conftest checks | [0004](../rfcs/0004-labels-and-annotations.md) | `accepted` |

## Source of the template

The template is an adaptation of the minimal template of [MADR](https://adr.github.io/madr/) 4.0.0. MADR has the license `MIT OR CC0-1.0` ([LICENSE](https://github.com/adr/madr/blob/main/LICENSE)). This repository uses it under CC0-1.0.
