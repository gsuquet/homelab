# Writing rules

This page lists the rules for all the documentation in this repository. The documentation uses English only.

## Structure

The documentation in `docs/` uses the [Diátaxis](https://diataxis.fr/) structure. Put each page in one section:

| Section | Folder | Content |
| --- | --- | --- |
| Tutorials | `docs/tutorials/` | Lessons that teach a new user, step by step. |
| How-to guides | `docs/how-to/` | Procedures for one task. |
| Reference | `docs/reference/` | Facts: tasks, schemas, policies, modules. |
| Explanation | `docs/explanation/` | Design decisions and the reasons for them. |

The RFCs and the ADRs are in `docs/records/`, outside of the Diátaxis sections. A record is a fixed document with a date and a status. Refer to [RFC 0001](../records/rfcs/0001-records-process.md).

## Language

The documentation uses [ASD-STE100](https://www.asd-ste100.org/) (Simplified Technical English). Vale checks a part of the rules. The Vale rules are in `.vale/styles/STE/`.

| Rule | Vale check | Level |
| --- | --- | --- |
| Use approved words. The check has a list of words that are not approved, with a replacement for each word. | `STE.Words` | Error |
| Write sentences with a maximum of 25 words. | `STE.SentenceLength` | Warning |
| Use the active voice. | `STE.Passive` | Warning |
| Do not use vague words, for example `just`, `simply` or `should`. | `STE.Vague` | Warning |

Vale does not check the 20-word limit for procedural sentences (ASD-STE100 rule 4.1). Vale cannot tell a procedural sentence from a descriptive sentence. Make sure that each procedure step has a maximum of 20 words.

Only errors fail `mise run lint:docs`. The warnings help you to write better text. To see them, run:

```bash
vale docs/how-to/render-manifests.md
```

Vale does not check these files:

- `CHANGELOG.md`, because git-cliff generates it from the commit messages.
- `docs/reference/ansible-roles/`, because a script generates these pages, and the migration removes Ansible.
- Files in `charts/` folders, because Helm charts can come from upstream projects.

## Add a word to the list

1. Add the word and its replacement to `.vale/styles/STE/Words.yml`.
2. Run `mise run lint:docs`.
3. Correct each file that the check shows.
