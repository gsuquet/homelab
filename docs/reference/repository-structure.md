# Reference: Repository Structure

This page shows the target tree of the repository and the legacy folders. [ADR 0016](../records/adrs/0016-use-the-target-repository-structure.md) decides the target tree. [RFC 0003](../records/rfcs/0003-repository-structure.md) gives the full discussion.

## Status of the tree

The target tree is not complete yet. This page marks each part that does not exist in the repository. The mark is `[not yet]`. Other pull requests (PRs) add these parts, as RFC 0003 ("Rollout") plans.

This page shows the tree as if two changes are complete:

- The PR that deletes `modules/bootstrap-agent-sandbox/` is merged. RFC 0003 ("Rollout", step 3.2) plans it.
- The PR that renames `LICENSE.md` to `LICENSE` is merged. [ADR 0021](../records/adrs/0021-use-the-community-health-files-and-the-mit-license.md) decides it.

RFC 0005 adds a folder `accounts/<account>/` for the provider accounts. Its ADRs are not merged yet, so this page does not show the folder. Refer to [RFC 0005](../records/rfcs/0005-repository-scope-and-naming.md).

## Target tree

```text
(the root of the repository)
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
│   ├── records/                      # RFCs and ADRs
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
- The agents RFC decides the place of the agent files. [ADR 0016](../records/adrs/0016-use-the-target-repository-structure.md) leaves them out of the target tree.
- The tooling RFC decides the choice of tools, their versions and their pins.
- `.github/CODEOWNERS` exists now. [ADR 0022](../records/adrs/0022-use-rfcs-and-adrs-to-record-decisions-without-codeowners.md) removes it.

### Items that do not exist yet

| Item | Decided in | Plan |
| --- | --- | --- |
| Issue forms and `config.yml` in `.github/` | [ADR 0012](../records/adrs/0012-use-the-label-taxonomy-the-issue-forms-and-the-pr-template.md), [ADR 0021](../records/adrs/0021-use-the-community-health-files-and-the-mit-license.md) | Not in the repository. |
| `README.md` and `CONTRIBUTING.md` in the Good Docs Project form | [ADR 0021](../records/adrs/0021-use-the-community-health-files-and-the-mit-license.md) | RFC 0003, "Rollout", step 3.4. |
| Removal of `CODE_OF_CONDUCT.md` and `SECURITY.md` from the root | [ADR 0021](../records/adrs/0021-use-the-community-health-files-and-the-mit-license.md) | The files move to `gsuquet/.github`. RFC 0003, "Rollout", step 3.4. |
| Removal of `.github/CODEOWNERS` | [ADR 0022](../records/adrs/0022-use-rfcs-and-adrs-to-record-decisions-without-codeowners.md) | RFC 0003, "Rollout", step 3.6. |
| Check for the folders at the root | [ADR 0016](../records/adrs/0016-use-the-target-repository-structure.md) | No check exists. The reviewer checks the tree. |
| Check for the Terraform file names and the other names marked "None yet" | [ADR 0017](../records/adrs/0017-use-the-terraform-module-and-instance-layout.md), [ADR 0019](../records/adrs/0019-use-the-naming-rules.md) | RFC 0003, "Rollout", step 3.7. |

## Terraform modules and instances

[ADR 0017](../records/adrs/0017-use-the-terraform-module-and-instance-layout.md) decides these files.

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

[ADR 0018](../records/adrs/0018-use-the-gitops-layout-by-cluster-and-a-rendered-app-of-apps.md) decides this layout.

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
    └── rendered/<component>/             # Generated manifests. Do not edit.
```

- A cluster selects its components in `cluster.yaml`. It can override values in `values/`.
- `mise run manifests:render` writes `rendered/<component>/`.
- The `argocd` chart renders one Application for each item of `cluster.yaml`. `dependsOn` gives each Application a sync wave.
- The `argocd` Application syncs `gitops/clusters/<cluster>/rendered/argocd/`. This folder holds the Applications and the AppProjects.
- An instance that runs Argo CD has a cluster folder with the same name. The `bootstrap-argocd` module applies the rendered Argo CD manifests of that cluster.

## Naming rules

[ADR 0019](../records/adrs/0019-use-the-naming-rules.md) decides the names. The general rule: the base of a folder or file name uses lowercase letters, digits and hyphens. It starts and ends with a letter or a digit. It has a maximum of 63 characters.

| Item | Rule | Example |
| --- | --- | --- |
| Module folder | `<layer>-<component>`. Layer is `substrate`, `cluster` or `bootstrap`. Maximum 63 characters. | `bootstrap-cilium` |
| Instance folder | DNS-1123 label. Maximum 40 characters. | `kind-local` |
| GitOps cluster folder | Equal to the instance name. Maximum 40 characters. | `gitops/clusters/kind-local/` |
| GitOps component folder | DNS-1123 label. Equal to the Application name. Unique in a cluster. Maximum 53 characters. | `cert-manager` |
| Namespace of a component | DNS-1123 label. Maximum 63 characters. | `cert-manager` |
| Rendered manifest file | `<kind>-<name>.yaml`, lowercase | `configmap-argocd-cm.yaml` |
| Terraform identifiers | Snake case. No resource type in the name. `this` for a single resource. | `api_server_address` |
| Terraform files | `terraform.tf`, `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `backend.tf`, `<topic>.tf` | `cluster-issuers.tf` |
| Template files | `<name>.<extension>.tftpl` | `cilium-values.yaml.tftpl` |
| Helm values | Camel case | `targetRevision` |
| Rego files | `<input>.rego` and `<input>_test.rego`. The package is `<input>`. The package of the test is `<input>_test`. | `kubernetes_test.rego` |
| Schemas | `<kind>.schema.json`. `kind` is the kebab-case form of the `kind` field. | `gitops-cluster.schema.json` |
| Records | `NNNN-short-title.md` | `0003-repository-structure.md` |
| Documentation pages | DNS-1123 label, with `.md` | `add-gitops-component.md` |

Exceptions:

- Names that a tool or GitHub requires keep their form. Examples: `README.md`, `SECURITY.md`, `Chart.yaml`, `LICENSE` and `.terraform.lock.hcl`.
- Names that start with `_` are not items. Examples: `modules/_template/` and `.mise/tasks/_base/`.
- Rego file names use underscores.
- A file extension can have more than one part, for example `.schema.json`.
- A rendered manifest file can have dots, for example `customresourcedefinition-applications.argoproj.io.yaml`.
- `schemas/tests/gitops-tree/` and `schemas/tests/instance-terraform/` name a tree, not a `kind`.

## Legacy folders

The production cluster `olympus` still runs from `ansible/`, `kubernetes/` and `scripts/`. These folders are not part of the target tree. [ADR 0020](../records/adrs/0020-keep-the-legacy-folders-deprecated-until-the-raspberry-pi-migration.md) keeps them in place, in the "deprecated" state, until the migration of the Raspberry Pi.

| Folder | Content now | Rule |
| --- | --- | --- |
| `ansible/` | `ansible.cfg`, `inventory/`, `playbooks/`, `roles/` | Deprecated. Do not add files. |
| `kubernetes/` | `applications/`, `bootstrap/`, `projects/`, `system/` | Deprecated. Do not add files. Do not move, rename or delete a folder: the production Argo CD reads these paths. |
| `scripts/` | `generate-ansible-docs.sh` | Deprecated. Do not add files. |

The rules of the "deprecated" state (ADR 0020):

- Each legacy folder has a `README.md`. Its first heading contains "Deprecated". It gives the reason and a link to RFC 0003. **[not yet]**
- The mise task `lint:legacy` fails when a change adds a file in a legacy folder. A move into a legacy folder counts as an added file. A change to an existing file stays possible. **[not yet]**
- The task ignores only `kubernetes/bootstrap/argo-cd/manifests/*.yaml`. **[not yet]**
- The file `.mise/tasks/lint/legacy-allowlist.txt` lists the paths that a migration fix can add. **[not yet]**
- The Vale, Renovate, pre-commit and render rules for these folders stay.

Removal: after `olympus` runs from `instances/` and `gitops/clusters/`, one PR removes the legacy folders, their rules, `lint:legacy`, its allowlist and this section.

Until `lint:legacy` exists, the reviewer checks that no PR adds a file in a legacy folder. The owner reviews each deletion in `kubernetes/`.
