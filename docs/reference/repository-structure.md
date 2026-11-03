# Repository structure

This page lists the folders and the root files of the repository. It also lists the files of a module and of an instance, the naming rules and the legacy folders.

## Tree

```text
(the root of the repository)
├── modules/                          # Terraform child modules. A module never runs alone.
│   ├── _template/                    # Template for a new module
│   └── <layer>-<component>/          # Layer: substrate, cluster or bootstrap
├── instances/
│   └── <instance>/                   # One Terraform root module for each instance
├── gitops/                           # GitOps sources
│   ├── infrastructure/<component>/sources/
│   ├── apps/<app>/sources/
│   └── clusters/<cluster>/           # Same name as the instance
├── policy/
│   ├── <input>/                      # Conftest policies and their tests
│   └── data/                         # Data files of the policies
├── schemas/
│   ├── <kind>.schema.json            # JSON Schemas
│   └── tests/                        # Fixtures
├── docs/
│   ├── tutorials/, how-to/, reference/, explanation/
│   ├── templates/                    # A template for each page type
│   └── archive/
├── .github/
│   ├── workflows/
│   ├── labeler.yml
│   ├── labels.yml
│   └── pull_request_template.md
├── .mise/
│   ├── config.toml
│   ├── mise.lock
│   └── tasks/                        # Shared shell functions are in tasks/_base/
├── .vale/                            # Vale styles
├── .vscode/extensions.json           # Recommended editor extensions
├── .editorconfig, .gitignore, .pre-commit-config.yaml, .shellcheckrc,
│   .terraform-docs.yml, .tflint.hcl, .typos.toml, .vale.ini, .yamllint.yaml
├── renovate.json
├── README.md, LICENSE, CONTRIBUTING.md, CHANGELOG.md
│
├── ansible/, kubernetes/             # Legacy folders
└── AGENTS.md, CLAUDE.md, GEMINI.md,  # Agent files
    .claude/, .gemini/, .entire/
```

| Folder or file | Content |
| --- | --- |
| `modules/` | Terraform child modules. Refer to [Files of a module](#files-of-a-module). |
| `instances/` | Terraform root modules, one for each instance. Refer to [Files of an instance](#files-of-an-instance). |
| `gitops/` | The GitOps sources and the rendered manifests of each cluster. Refer to [GitOps layout](gitops-layout.md). |
| `policy/` | The Conftest policies. Refer to [Policies](policies.md). |
| `schemas/` | The JSON Schemas of the metadata files, and their fixtures. Refer to [Schemas](schemas.md). |
| `docs/` | The documentation. Refer to [Writing rules](writing-rules.md). |
| `.github/` | The workflows, the labeler rules, the label list and the pull request template. |
| `.mise/` | The tools, their lock file and the tasks. Refer to [Mise tasks](mise-tasks.md) and [Tools](tools.md). |
| `ansible/`, `kubernetes/` | The legacy folders. Refer to [Legacy folders](#legacy-folders). |
| `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude/`, `.gemini/`, `.entire/` | The instruction files and the settings of the agents. A module can also have an `AGENTS.md` file. |

- A shell script is a mise task, in `.mise/tasks/`. A shared shell function is in `.mise/tasks/_base/`.
- Each tool reads its configuration file from the root. `lint:terraform` passes `--config`, because `--chdir` moves TFLint into each module.
- Modules have no `examples/` folder.
- The repository has no `.github/CODEOWNERS` file.

## Root files

| File | Content |
| --- | --- |
| `README.md` | The entry page of the repository. |
| `LICENSE` | The MIT license. It applies to all the repository, `docs/` too, except upstream copies, which keep their own license. |
| `CONTRIBUTING.md` | The tasks, the checks and the review flow for a change. |
| `CHANGELOG.md` | The list of changes. `mise run changelog:generate` writes it from the commit messages with git-cliff. |

The repository has no `CODE_OF_CONDUCT.md`, `SECURITY.md` or `SUPPORT.md`. GitHub uses the default files of the shared repository [`gsuquet/.github`](https://github.com/gsuquet/.github):

| File | Content |
| --- | --- |
| [`CODE_OF_CONDUCT.md`](https://github.com/gsuquet/.github/blob/main/CODE_OF_CONDUCT.md) | The Contributor Covenant, version 2.0. |
| [`SECURITY.md`](https://github.com/gsuquet/.github/blob/main/SECURITY.md) | How to report a vulnerability: GitHub private vulnerability reporting first, and email second. |
| [`SUPPORT.md`](https://github.com/gsuquet/.github/blob/main/SUPPORT.md) | How to get help. |

Private vulnerability reporting is on in the settings of this repository.

## Files of a module

| File or folder | Necessary | Content |
| --- | --- | --- |
| `module.yaml` | Yes | Metadata. `schemas/module.schema.json` validates it. |
| `README.md` | Yes | Purpose, use and the generated `terraform-docs` block. |
| `terraform.tf` | Yes | The `terraform` block: `required_version` and `required_providers`. |
| `main.tf` | Yes | The primary resources. |
| `variables.tf` | Yes | The input variables. |
| `outputs.tf` | Yes | The outputs. |
| `.terraform.lock.hcl` | Yes, but not in `_template/` | The provider checksums. `mise run tf:lock` writes it. |
| `AGENTS.md` | No | Instructions for the agents that change the module. |
| `locals.tf` | No | Local values that more than one file uses. |
| `<topic>.tf` | No | A group of related resources, for example `namespace.tf`. |
| `templates/` | No | Files for `templatefile()`, with the extension `.tftpl`. |
| `manifests/` | No | Copies of upstream manifests, with no change. |

- A module has no `providers.tf` and no `backend.tf`. The instance configures the providers and the state.
- A copy of upstream content keeps its license. The folder of the copy holds the license file of the source. The `README.md` of the module names the source, the version and the license.
- `docs/reference/terraform-modules/<module>/index.md` is a generated copy of the `README.md` of the module. `mise run doc:check` makes sure that the copy is equal to its source.

## Files of an instance

| File | Necessary | Content |
| --- | --- | --- |
| `instance.yaml` | Yes | Metadata. `schemas/instance.schema.json` validates it. |
| `terraform.tf` | Yes | The `terraform` block. |
| `providers.tf` | Yes | The `provider` blocks. |
| `main.tf` | Yes | The calls to the modules. |
| `variables.tf` | Yes | The input variables. |
| `outputs.tf` | Yes | The outputs. |
| `backend.tf` | If the state is remote | The `backend` or `cloud` block. |
| `.terraform.lock.hcl` | Yes | The provider checksums. |

- `.gitignore` blocks `*.tfvars`, `*.tfvars.json`, `*.tfstate` and `*.tfstate.*`.
- An instance that runs Argo CD has a folder with the same name in `gitops/clusters/`.

## Naming rules

The general rule: the base of a folder or file name uses lowercase letters, digits and hyphens. It starts and ends with a letter or a digit. It has a maximum of 63 characters.

| Item | Rule | Example | Check |
| --- | --- | --- | --- |
| Module folder | `<layer>-<component>`. Layer is `substrate`, `cluster` or `bootstrap`. Maximum 63 characters. | `bootstrap-cilium` | `module.schema.json`. The folder name equals `name`. |
| Instance folder | DNS-1123 label. Maximum 40 characters. | `kind-local` | `instance.schema.json` |
| GitOps cluster folder | Equal to the instance name. Maximum 40 characters. | `gitops/clusters/kind-local/` | `gitops-cluster.schema.json`, `instance-checks.sh` |
| GitOps component folder | DNS-1123 label. Equal to the Application name. Unique in a cluster. Maximum 53 characters, the limit of a Helm release name. | `cert-manager` | `gitops-cluster.schema.json`, `instance-checks.sh` |
| Namespace of a component | DNS-1123 label. Maximum 63 characters. | `cert-manager` | `gitops-cluster.schema.json` |
| Rendered manifest file | `[upstream--]<kind>-<name>.yaml`, lowercase. The prefix `upstream--` marks a resource from an upstream chart. | `namespace-argocd.yaml`, `upstream--configmap-argocd-cm.yaml` | `manifests:render` writes it. |
| Terraform identifiers | Snake case. No resource type in the name. `this` for a single resource. | `api_server_address` | TFLint checks the snake case. The review checks the rest. |
| Terraform files | `terraform.tf`, `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `backend.tf`, `<topic>.tf` | `cluster-issuers.tf` | The review |
| Template files | `<name>.<extension>.tftpl` | `cilium-values.yaml.tftpl` | The review |
| Helm values | Camel case | `targetRevision` | The review |
| Rego files | `<input>.rego` and `<input>_test.rego`. The package is `<input>`. The package of the test is `<input>_test`. | `kubernetes_test.rego` | The review |
| Schemas | `<kind>.schema.json`. `kind` is the kebab-case form of the `kind` field. | `gitops-cluster.schema.json` | The review |
| Documentation pages | DNS-1123 label, with `.md` | `add-a-gitops-component.md` | The review |

Exceptions:

- Names that a tool or GitHub requires keep their form. Examples: `README.md`, `SECURITY.md`, `Chart.yaml`, `LICENSE` and `.terraform.lock.hcl`.
- Names that start with `_` are not items. Examples: `modules/_template/` and `.mise/tasks/_base/`.
- Rego file names use underscores, because a Rego package name cannot have a hyphen.
- A file extension can have more than one part, for example `.schema.json`.
- A rendered manifest file can have dots, for example `upstream--customresourcedefinition-applications.argoproj.io.yaml`.
- The prefix of an upstream rendered manifest file has a double hyphen: `upstream--`. Refer to [GitOps layout](gitops-layout.md#rendered-files).
- `schemas/tests/gitops-tree/` and `schemas/tests/instance-terraform/` name a tree, not a `kind`.

## Legacy folders

The production cluster `olympus` runs from `ansible/` and `kubernetes/`.

| Folder | Content | Rule |
| --- | --- | --- |
| `ansible/` | `ansible.cfg`, `inventory/`, `playbooks/`, `roles/` | No new files. |
| `kubernetes/` | `applications/`, `bootstrap/`, `projects/`, `system/` | No new files. No move, rename or deletion of a folder. |

- The Argo CD of `olympus` reads `kubernetes/` at `HEAD`. Its Applications and ApplicationSets in `kubernetes/bootstrap/argo-cd/` have `prune: true` and the finalizer `resources-finalizer.argocd.argoproj.io`.
- The ApplicationSets make one Application for each folder in `kubernetes/applications/` and `kubernetes/system/`. A deletion of one of these folders deletes that production Application and its resources.
- A PR can change an existing file in a legacy folder. The review checks that no PR adds a file in a legacy folder.
- The Vale, Renovate, pre-commit and render rules for these folders stay in force.

## Related pages

- [Repository structure (explanation)](../explanation/repository-structure.md): why the tree, the file layouts and the naming rules have their form.
- [Repository scope](../explanation/repository-scope.md): what the repository holds, and why.
- [GitOps layout](gitops-layout.md): the files in `gitops/`.
- [Schemas](schemas.md): the rules of the metadata files.
- [Add a GitOps component](../how-to/add-a-gitops-component.md)
