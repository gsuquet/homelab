# Reference: Repository Structure

This page shows the target tree of the repository and the legacy folders. The reasons are in [Repository structure (explanation)](../explanation/repository-structure.md).

## Status of the tree

The target tree is not complete yet. This page marks each part that does not exist in the repository. The mark is [not yet]. Later pull requests (PRs) add these parts.

The folder `accounts/<account>/` holds one Terraform root module for each provider account. Its files and rules are in [Provider accounts](provider-accounts.md).

## Target tree

```text
(the root of the repository)
├── accounts/<account>/               # [not yet] One Terraform root module for each provider account
├── modules/                          # Terraform child modules. A module never runs alone.
│   ├── _template/                    # Template for a new module
│   └── <layer>-<component>/          # Layer: substrate, cluster or bootstrap
├── instances/
│   └── <instance>/                   # One Terraform root module for each instance
├── gitops/                           # GitOps sources
│   ├── infrastructure/
│   │   └── <component>/sources/      # Components that can change cluster-scoped resources
│   ├── apps/
│   │   └── <app>/sources/            # Applications
│   └── clusters/
│       └── <cluster>/                # Same name as the instance
│           ├── cluster.yaml
│           ├── values/<component>.yaml
│           └── rendered/<component>/
├── policy/
│   └── <input>/                      # Conftest policies and their tests
├── schemas/
│   ├── <kind>.schema.json            # JSON Schemas
│   └── tests/                        # Fixtures
├── docs/
│   ├── tutorials/, how-to/, reference/, explanation/
│   └── archive/
├── .github/
│   ├── workflows/
│   ├── labeler.yml
│   ├── ISSUE_TEMPLATE/               # [not yet] Issue forms and config.yml
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
├── ansible/, kubernetes/, scripts/   # Legacy. Not part of the target tree.
└── AGENTS.md, CLAUDE.md, GEMINI.md,  # Agent files. Out of scope.
    .claude/, .gemini/, .entire/
```

Notes on the tree:

- `ansible/`, `kubernetes/` and `scripts/` are legacy folders. Refer to [Legacy folders](#legacy-folders).
- The agent files are outside the target tree. The place for them is not decided yet.
- The choice of tools, their versions and their pins is outside the target tree.
- A script that is not a mise task has no place in the target tree. A shared shell function goes in `.mise/tasks/_base/`.
- Each tool reads its configuration from the default location of the tool. The repository does not use a flag to change that location.
- Modules have no `examples/` folder. The instances are the examples.
- There is no `FUNDING.yml`, here or in `gsuquet/.github`.

### Open work

| Item | Status | Issue |
| --- | --- | --- |
| Issue forms and `config.yml` in `.github/` | Not done. The generic forms can go to `gsuquet/.github` instead. | #200 |
| `README.md` and `CONTRIBUTING.md` in the Good Docs Project form | Not done. | #220 |
| Move of `CODE_OF_CONDUCT.md` and `SECURITY.md` out of the root, and a new `SUPPORT.md` | Not done. The files go to `gsuquet/.github`, and this repository keeps no copy. | #220, after #214 |
| Check for the folders at the root | No check exists. The reviewer checks the tree. | #221 |
| Check for the Terraform file names and the other names with "None yet" in the naming table | Not done. | #221 |
| The deprecation `README.md` files, `lint:legacy` and its allowlist | Not done. | #219 |
| The repository description, the topics and the docs link of the community profile | Not done. These are manual settings. | #222 |
| The removal of the legacy folders, after the migration of the Raspberry Pi | Blocked by the migration. | #223 |
| The folder `accounts/` | Not done. | #231 |

## Terraform modules and instances

### Files of a module

| File or folder | Necessary | Content |
| --- | --- | --- |
| `module.yaml` | Yes | Metadata. `schemas/module.schema.json` validates it. |
| `README.md` | Yes | Purpose, use and the generated `terraform-docs` block. |
| `terraform.tf` | Yes | The `terraform` block: `required_version` and `required_providers`. |
| `main.tf` | Yes | The primary resources. |
| `variables.tf` | Yes | The input variables. |
| `outputs.tf` | Yes | The outputs. |
| `.terraform.lock.hcl` | Yes | The provider checksums. `mise run tf:lock` writes it. |
| `locals.tf` | No | Local values that more than one file uses. |
| `<topic>.tf` | No | A group of related resources, for example `namespace.tf`. |
| `templates/` | No | Files for `templatefile()`, with the extension `.tftpl`. |
| `manifests/` | No | Copies of upstream manifests, without change. |
| `charts/<chart>/` | No | A copy of an upstream chart, without change. |

- A module has no `providers.tf` and no `backend.tf`. The instance configures the providers and the state.
- A copy of upstream content keeps the license of its source. The folder of the copy holds the license file of the source. `README.md` of the module names the source, the version and the license.

### Files of an instance

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

- The repository does not commit `*.tfvars`. `.gitignore` blocks them.

### Documentation of the modules

`docs/reference/terraform-modules/<module>/index.md` is a generated copy of the `README.md` of the module. `mise run doc:check` makes sure that the copy is equal to its source.

## GitOps layout

```text
gitops/
├── infrastructure/<component>/sources/   # Components that can change cluster-scoped resources
│   ├── Chart.yaml                        # Umbrella chart. The upstream chart has an exact version.
│   ├── values.yaml                       # Values for all clusters
│   └── templates/                        # namespace.yaml, and more manifests
├── apps/<app>/sources/                   # The same layout
└── clusters/<cluster>/
    ├── cluster.yaml                      # Entry point: the components of the cluster
    ├── values/<component>.yaml           # Optional. Values for this cluster only
    └── rendered/<component>/             # Generated manifests. The render task writes them.
```

- A cluster selects its components in `cluster.yaml`. It can override values in `values/`.
- `mise run manifests:render` writes `rendered/<component>/`.
- The `argocd` chart renders one Application for each item of `cluster.yaml`. `dependsOn` gives each Application a sync wave.
- The `argocd` Application syncs `gitops/clusters/<cluster>/rendered/argocd/`. This folder holds the Applications and the AppProjects.
- An instance that runs Argo CD has a cluster folder with the same name. The `bootstrap-argocd` module applies the rendered Argo CD manifests of that cluster.

## Naming rules

The general rule: the base of a folder or file name uses lowercase letters, digits and hyphens. It starts and ends with a letter or a digit. It has a maximum of 63 characters.

| Item | Rule | Example | Check |
| --- | --- | --- | --- |
| Module folder | `<layer>-<component>`. Layer is `substrate`, `cluster` or `bootstrap`. Maximum 63 characters. | `bootstrap-cilium` | `module.schema.json`. The folder name equals `name`. |
| Instance folder | DNS-1123 label. Maximum 40 characters. | `kind-local` | `instance.schema.json` |
| GitOps cluster folder | Equal to the instance name. Maximum 40 characters. | `gitops/clusters/kind-local/` | `gitops-cluster.schema.json`, `instance-checks.sh` |
| GitOps component folder | DNS-1123 label. Equal to the Application name. Unique in a cluster. Maximum 53 characters, the limit of a Helm release name. | `cert-manager` | `gitops-cluster.schema.json`, `instance-checks.sh` |
| Namespace of a component | DNS-1123 label. Maximum 63 characters. | `cert-manager` | `gitops-cluster.schema.json` |
| Rendered manifest file | `<kind>-<name>.yaml`, lowercase | `configmap-argocd-cm.yaml` | `manifests:render` writes it |
| Terraform identifiers | Snake case. No resource type in the name. `this` for a single resource. | `api_server_address` | TFLint |
| Terraform files | `terraform.tf`, `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `backend.tf`, `<topic>.tf` | `cluster-issuers.tf` | None yet |
| Template files | `<name>.<extension>.tftpl` | `cilium-values.yaml.tftpl` | None yet |
| Helm values | Camel case | `targetRevision` | None yet |
| Rego files | `<input>.rego` and `<input>_test.rego`. The package is `<input>`. The package of the test is `<input>_test`. | `kubernetes_test.rego` | None yet |
| Schemas | `<kind>.schema.json`. `kind` is the kebab-case form of the `kind` field. | `gitops-cluster.schema.json` | None yet |
| Documentation pages | DNS-1123 label, with `.md` | `add-gitops-component.md` | None yet |

Exceptions:

- Names that a tool or GitHub requires keep their form. Examples: `README.md`, `SECURITY.md`, `Chart.yaml`, `LICENSE` and `.terraform.lock.hcl`.
- Names that start with `_` are not items. Examples: `modules/_template/` and `.mise/tasks/_base/`.
- Rego file names use underscores, because a Rego package name cannot have a hyphen.
- A file extension can have more than one part, for example `.schema.json`.
- A rendered manifest file can have dots, for example `customresourcedefinition-applications.argoproj.io.yaml`.
- `schemas/tests/gitops-tree/` and `schemas/tests/instance-terraform/` name a tree, not a `kind`.

## Community health files and the license

- The root keeps `README.md`, `LICENSE`, `CONTRIBUTING.md` and `CHANGELOG.md`.
- `CODE_OF_CONDUCT.md` (Contributor Covenant 2.0, contact `contact@gsuquet.com`), `SECURITY.md`, `SUPPORT.md` and a generic `CONTRIBUTING.md` go to `gsuquet/.github` (#220). No `FUNDING.yml`.
- The shared `SECURITY.md` names GitHub private vulnerability reporting first, "in the Security tab of the repository, if it is on", and email to `contact@gsuquet.com` second. It does not promise private reporting for each repository.
- Private vulnerability reporting stays on in the settings of this repository, because a default `SECURITY.md` is not in the clones, the forks or the downloads.
- The MIT license applies to all the repository, also to `docs/`. Each copy of upstream content keeps its upstream license.

## Legacy folders

The production cluster `olympus` still runs from `ansible/`, `kubernetes/` and `scripts/`. These folders are not part of the target tree. They stay in place, in the "deprecated" state, until the migration of the Raspberry Pi.

| Folder | Content now | Rule |
| --- | --- | --- |
| `ansible/` | `ansible.cfg`, `inventory/`, `playbooks/`, `roles/` | Deprecated. The rule: no new files. |
| `kubernetes/` | `applications/`, `bootstrap/`, `projects/`, `system/` | Deprecated. The rule: no new files. A move, a rename or a deletion of a folder deletes the production workloads, because the production Argo CD reads these paths. |
| `scripts/` | `generate-ansible-docs.sh` | Deprecated. The rule: no new files. |

The rules of the "deprecated" state:

- Each legacy folder has a `README.md`. Its first heading contains "Deprecated". It gives the reason. [not yet]
- The mise task `lint:legacy` fails when a change adds a file in a legacy folder. A move into a legacy folder counts as an added file. A change to an existing file stays possible. [not yet]
- The task ignores only `kubernetes/bootstrap/argo-cd/manifests/*.yaml`. [not yet]
- The file `.mise/tasks/lint/legacy-allowlist.txt` lists the paths that a migration fix can add. [not yet]
- The Vale, Renovate, pre-commit and render rules for these folders stay.

Removal: after `olympus` runs from `instances/` and `gitops/clusters/`, one PR removes the legacy folders, their rules, `lint:legacy`, its allowlist and this section.

Until `lint:legacy` exists, the reviewer checks that no PR adds a file in a legacy folder. Each deletion in `kubernetes/` needs a careful review, because it deletes a production Application.
