# Writing rules

These rules apply to all the documentation in `docs/`. The documentation uses English only. `AGENTS.md`, `CONTRIBUTING.md` and the `README.md` files are outside `docs/`. They use the ASD-STE100 rules. The page types and the voice rules apply only in `docs/`.

## Page types

The documentation uses the [Diátaxis](https://diataxis.fr/) structure. Each page has one type, and each type has one folder.

| Type | Folder | Reader need | Language | Template |
| --- | --- | --- | --- | --- |
| Tutorial | `docs/tutorials/` | Learn by doing, with a guide. | "We", step by step, to a visible result. | [Tutorial](../templates/tutorial.md) |
| How-to guide | `docs/how-to/` | Do one task, with competence. | The imperative. | [How-to guide](../templates/how-to.md) |
| Reference | `docs/reference/` | Look up a fact. | Neutral statements. | [Reference](../templates/reference.md) |
| Explanation | `docs/explanation/` | Understand why. | A discussion, with context and alternatives. | [Explanation](../templates/explanation.md) |

These rules apply to all types:

- A page has one type. Content of a different type goes to a page of that type, and the page links to it.
- A page links to the matching pages of the other types, when they exist. The link list is the last section of the page: "Next steps" in a tutorial, "Related pages" in the other types.
- A new subject starts from a plan, outside the repository. The pages then describe the system as it is once built, and the code follows. Refer to [Work rules](work-rules.md#workflow-steps).

### Tutorials

Source: <https://diataxis.fr/tutorials/>

| Rule | Example |
| --- | --- |
| A tutorial uses "we". The writer and the learner do the work together. | "Now we start the cluster." |
| The first paragraph tells the result. It does not promise what the learner learns. | "In this tutorial, we start a Kubernetes cluster on our computer." |
| A tutorial has one path, with no choices and no alternatives. | One command for each step, with no options. |
| Each step has a visible result. The page shows the expected output. | "The output ends like this:", then a `text` block. |
| The page tells the learner what to look at. | "Notice the two `Apply complete!` lines." "Let's check it with kubectl." |
| The explanation is a minimum. The page links to the explanation page. | One sentence, then a link in "Next steps". |
| Each step is reliable. The tutorial works each time, on each supported computer. | List the requirements in "Before we start". |
| The last section tells what the learner did. | A "What we did" section. |

The title tells the result, in the imperative: "Run your first local cluster".

### How-to guides

Source: <https://diataxis.fr/how-to-guides/>

| Rule | Example |
| --- | --- |
| A how-to guide uses the imperative. The reader knows the goal. | "Restart Colima with the new size." |
| The first sentence tells the task. | "This guide shows how to give the Colima VM more CPUs or memory." |
| The page tells when to do the task. | "Resize the VM when one of these occurs:", then a list. |
| A condition and its action are in one sentence. | "If the task printed a warning, use the command in the warning." |
| A how-to guide has only actions. It does not teach or explain. | Link to the reference page for the full list of options. |
| The steps have numbers, in the order of their dependencies. | Each step has a maximum of 20 words. |
| Each section has the name of its task, in the imperative. No section has the name "Procedure". | "## Resize the VM", "## Let the task set the size" |
| Requirements go in an optional "Before you start" section, before the first task. | The tools, the access and the state that the task needs. |
| The guide starts and stops at a point that has a meaning for the reader. | The guide stops when the task is complete. |

The title is the task, in the imperative: "Resize the Colima VM". It does not start with "How to".

### Reference

Source: <https://diataxis.fr/reference/>

| Rule | Example |
| --- | --- |
| A reference page only describes. It has no instructions, opinions or reasons. | "`instance:down` destroys an instance." |
| The pages mirror the structure of the repository. | One page for each task group, module or schema. One section for each part. |
| All pages of one kind use the same pattern. | Syntax, then arguments, steps, environment variables and exit status. |
| The page lists the facts: commands, arguments, defaults, limits and errors. | A table with one row for each item. |
| Each constraint is a firm rule. | "Each instance that uses `cluster-kind` must have this output." |
| Examples are short. | `mise run instance:up kind-local` |

The title is the name of the thing that the page describes: "Instance tasks".

### Explanation

Source: <https://diataxis.fr/explanation/>

| Rule | Example |
| --- | --- |
| An explanation page discusses why: the reasons for the design and its constraints. | "Kind runs plain upstream Kubernetes, set up with kubeadm." |
| The page gives the context and the connections to other subjects. | "The managed clusters of GKE and AKS also run upstream Kubernetes." |
| The page tells the limits of the design. | A "What Kind does not reproduce" section. |
| The page compares the alternatives, with a reason for each judgement. | "minikube usually runs one node, and it is slower than Kind." |
| The page tells how the parts work together only to explain a behavior. It has no procedure. | "A Kind node is a container, so it shares the kernel of the Colima VM." |
| The page has one subject. A "why" question sets the limits of the page. | "Why does the platform run on a local cluster first?" |

The title is the subject or the question: "Why the platform runs on a local cluster first".

## Voice and tense

A page describes the system as built, in the present tense, also before the code exists. When the code differs from a page, the next change corrects the page.

| Rule | Not permitted | Vale check |
| --- | --- | --- |
| A page has no first person singular. It uses the language of its type. | `I`, `my`, `me`, `mine`, `myself` | `Homelab.FirstPerson` |
| A page does not name a person by a role. It states the rule with no person, or it names the agents. | `owner`, `maintainer`, `the human`, and `the user` as a person, not an account | `Homelab.PersonRoles`, for `owner` and `maintainer` |
| A page describes the system as built. It does not mark a part as missing. | `[not yet]` | `Homelab.NotYet` |
| A page does not refer to a numbered question of a plan or a review. It states the answer as a fact. | `Q3`, `question 3` | `Homelab.QuestionNumbers` |
| A page has no open decisions, done criteria or stop rules. Design work is in a plan, outside the repository. | "We decide this later." | None |
| A page does not refer to proposals or decision records. It states the rule, or it links to the page that holds it. | `RFC 0nnn` | `mise run lint:records` |
| A page does not tell the history of a change. The Git history and the PRs keep it. | `was`, `used to`, `moved from`, `previously` | None |

A page names AI agents "agents". A role word in code, for example the label key `ownership.<p>/owner` or the flag `--owner`, is in backticks. Vale does not check it.

## ASD-STE100

The documentation uses [ASD-STE100](https://www.asd-ste100.org/) (Simplified Technical English): short sentences and approved words, in the language of each page type. Vale checks a part of the rules. The STE rules are in `.vale/styles/STE/`.

| Rule | Vale check | Level |
| --- | --- | --- |
| A page uses approved words. Refer to [Word list](#word-list). | `STE.Words` | Error |
| A descriptive sentence has a maximum of 25 words (ASD-STE100 rule 5.1). | `STE.SentenceLength` | Warning |
| A sentence uses the active voice. | `STE.Passive` | Warning |
| A page has no vague words: `basically`, `easily`, `just`, `simply`, `should` or `very`. | `STE.Vague` | Warning |

Vale does not check the 20-word limit for procedural sentences (ASD-STE100 rule 4.1). Vale cannot tell a procedural sentence from a descriptive sentence. Each procedure step has a maximum of 20 words.

### Word list

`STE.Words` has these words that are not approved. Vale shows the replacement for each word. The check ignores the case of the letters.

| Word | Replacement |
| --- | --- |
| `accomplish` | `do` |
| `additional` | `more` |
| `approximately` | `about` |
| `assist` | `help` |
| `commence` | `start` |
| `demonstrate` | `show` |
| `ensure` | `make sure` |
| `facilitate` | `help` |
| `however` | `but` |
| `in order to` | `to` |
| `indicate` | `show` |
| `initiate` | `start` |
| `leverage` | `use` |
| `numerous` | `many` |
| `obtain` | `get` |
| `prior to` | `before` |
| `provide` | `give` |
| `regarding` | `about` |
| `subsequently` | `then` |
| `sufficient` | `enough` |
| `terminate` | `stop` |
| `utilize` | `use` |

To add a word, refer to [Add a word to the STE word list](../how-to/add-a-word-to-the-ste-word-list.md).

## File format

The files stay compatible with an MkDocs site.

- A page has one `#` title, on its first line. The other headings are `##` and lower, with no skipped level.
- A link to another page is a relative link to its `.md` file, for example `../how-to/resize-the-colima-vm.md#resize-the-vm`. A link to a file outside `docs/` is a relative path from the page. A link to a web page is a full `https://` URL.
- A page uses standard Markdown: headings, lists, tables, fenced code blocks with a language, and inline code. A page does not use GitHub-only syntax, for example the `> [!NOTE]` alerts.
- A diagram is a Mermaid fenced code block or an SVG file. Vale does not check code blocks, so a short text version of each diagram is next to it.
- A file name is the title in lowercase, with hyphens: `resize-the-colima-vm.md`.
- A folder name in `docs/` can become a navigation section of the site.

## Vale

`mise run lint:docs` runs Vale on each Markdown file that Git tracks. Only errors fail the check. To see the warnings too, run Vale on one file:

```bash
vale docs/how-to/render-manifests.md
```

`.vale.ini` sets the styles for each group of files:

| Files | Styles |
| --- | --- |
| `docs/**/*.md` | `STE`, `Homelab` |
| The other `*.md` files | `STE` |
| `CHANGELOG.md` | None. git-cliff makes it from the commit messages. |
| `docs/reference/ansible-roles/` | None. A script makes these pages from the role tasks. |
| Files in `charts/` folders | None. Helm charts can come from upstream projects. |
| `docs/archive/` | None. The archived pages get no updates. |

The `Homelab` rules are in `.vale/styles/Homelab/`. Their level is error.

## Templates

The templates in `docs/templates/` have the structure of each page type. A new page starts as a copy of the template of its type, in the folder of the type. The text in curly braces is a placeholder. The HTML comments tell what each section holds. A finished page has no placeholders and no template comments.

`docs/templates/` is not a navigation section. A future site excludes it.

- [Tutorial](../templates/tutorial.md)
- [How-to guide](../templates/how-to.md)
- [Reference](../templates/reference.md)
- [Explanation](../templates/explanation.md)
- `CHANGELOG.md`, because git-cliff generates it from the commit messages.
- Files in `charts/` folders, because Helm charts can come from upstream projects.

## Related pages

- [Add a word to the STE word list](../how-to/add-a-word-to-the-ste-word-list.md)
- [Work rules](work-rules.md)
- [Mise tasks](mise-tasks.md)
