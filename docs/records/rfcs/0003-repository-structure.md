---
rfc: "0003"
status: draft
start-date: 2026-10-31
pr: 168
---

# RFC 0003: Repository structure

## Summary

This RFC proposes the target structure of the repository. It gives the top-level folders and the layout of a Terraform module, an instance and a GitOps component. It also gives the place of the policies, the schemas, the documentation and the tool configuration. It gives one set of naming rules for folders, modules, instances, components and files. It also gives the target set of community health files, and it compares options for the license. The RFC compares the current tree with the community standards that the owner selected. These are the GitHub community profile, the HashiCorp module structure, terraform-best-practices.com, the Helm best practices and the Argo CD guides. `ansible/` and `kubernetes/` are not part of the target structure. They stay, with a deprecation mark, until the migration of the Raspberry Pi is complete. Then one PR removes them.

## Motivation

The repository has two designs in one tree. The new design uses `modules/`, `instances/` and `gitops/`. The old design uses `ansible/` and `kubernetes/`, and the production cluster `olympus` still runs from it. Nobody wrote down which folders belong to the target, which names are correct, or where a new file goes.

[RFC 0001](0001-records-process.md) says that no earlier decision stays in force on its own authority. The current layout of `gitops/` came from PR #163, without an RFC. Thus this RFC must confirm it or replace it.

These problems exist now:

- [Repository structure](../../reference/repository-structure.md) mixes the two designs. It does not tell which folders the migration removes.
- `README.md` and `SECURITY.md` describe the old design: Ansible, Sealed Secrets, UFW and K3s. A new reader gets a wrong view of the repository.
- The naming rules are in three schemas and one `README.md`, but not in one place. Some rules have no check.
- The module template (`modules/_template/README.md`) lists open questions about file names. Nobody answered them.
- `modules/bootstrap-agent-sandbox/charts/agent-sandbox/` holds a copy of an upstream chart. Its source has the Apache-2.0 license, but the folder has no license file.
- GitHub reads `LICENSE.md` as MIT. Nobody compared MIT with the other licenses for a public infrastructure repository.

Use cases:

- **An author adds a Terraform module.** The author copies `modules/_template/`, names the folder `<layer>-<component>`, and knows which files the module must have.
- **An author adds a GitOps component.** The author knows where the chart goes, where the values for one cluster go, and where the rendered manifests go.
- **An author adds an instance.** The author uses the same name in `instances/<name>/` and `gitops/clusters/<name>/`.
- **A visitor opens the repository on GitHub.** The visitor finds a correct `README.md`, a license, a security policy and the rules to contribute.
- **The migration of the Raspberry Pi is complete.** The owner knows which folders, tasks and rules to remove, and in which PR.

## Proposal

### The target tree

The target tree has six groups of top-level content:

- Infrastructure code: `modules/` and `instances/`.
- GitOps sources: `gitops/`.
- Checks: `policy/` and `schemas/`.
- Documentation: `docs/`.
- Tool and GitHub configuration: `.mise/`, `.github/`, `.vale/` and the configuration files at the root.
- Community health files at the root.

The diagram shows the target tree. The legacy folders are outside of it.

```mermaid
flowchart TD
    root["homelab/"]
    root --> modules["modules/#lt;layer#gt;-#lt;component#gt;/"]
    root --> instances["instances/#lt;instance#gt;/"]
    root --> gitops["gitops/"]
    gitops --> ginfra["infrastructure/#lt;component#gt;/sources/"]
    gitops --> gapps["apps/#lt;app#gt;/sources/"]
    gitops --> gclusters["clusters/#lt;cluster#gt;/"]
    root --> policy["policy/#lt;input#gt;/"]
    root --> schemas["schemas/"]
    root --> docs["docs/"]
    root --> tooling[".mise/, .github/, .vale/, tool configuration files"]
    root --> health["README.md, LICENSE, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, SUPPORT.md"]
    legacy["ansible/, kubernetes/, scripts/ (legacy, removed after the migration)"]
    root -.-> legacy
```

The same tree in text:

```text
homelab/
├── modules/<layer>-<component>/     # Terraform modules (child modules)
├── instances/<instance>/            # Terraform root modules, one for each instance
├── gitops/
│   ├── infrastructure/<component>/sources/
│   ├── apps/<app>/sources/
│   └── clusters/<cluster>/          # cluster.yaml, values/, rendered/
├── policy/<input>/                  # Conftest policies and their tests
├── schemas/                         # JSON Schemas and their test fixtures
├── docs/                            # Diátaxis sections, records/, archive/
├── .github/                         # CODEOWNERS, workflows, templates
├── .mise/                           # config.toml, mise.lock, tasks/
├── .vale/                           # Vale styles
├── <tool configuration files>       # .editorconfig, .tflint.hcl, .yamllint.yaml, ...
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── SUPPORT.md
├── CHANGELOG.md
└── renovate.json
```

`ansible/`, `kubernetes/` and `scripts/` are legacy. They are not in the target tree. Refer to "Legacy folders".

### From modules to clusters

Terraform and Argo CD have different jobs. Terraform creates a cluster and installs the minimum that Argo CD needs, one time. Argo CD reads Git all the time and applies the rest. Thus the code for each tool stays in its own folders. The instance name connects them.

The diagram shows the flow. In text: an instance calls the modules. One module, `bootstrap-argocd`, applies the rendered Argo CD manifests of the cluster with the same name. Then Argo CD syncs the rendered folder of each component in `cluster.yaml`. Each rendered folder comes from a component in `gitops/infrastructure/` or `gitops/apps/`.

```mermaid
flowchart LR
    subgraph terraform["Terraform: one time"]
        M["modules/#lt;layer#gt;-#lt;component#gt;/"]
        I["instances/#lt;name#gt;/"]
        I -->|calls| M
    end
    subgraph git["Git: gitops/"]
        C["infrastructure/ and apps/: #lt;component#gt;/sources/"]
        CL["clusters/#lt;name#gt;/cluster.yaml"]
        R["clusters/#lt;name#gt;/rendered/#lt;component#gt;/"]
        C -->|mise run manifests:render| R
        CL -->|selects components| R
    end
    I -->|bootstrap-argocd applies rendered/argocd/| A["Argo CD on cluster #lt;name#gt;"]
    A -->|syncs all the time| R
```

### What changes for an author

- To add a module, copy `modules/_template/` to `modules/<layer>-<component>/`.
- To add an instance, create `instances/<name>/`. If the instance runs Argo CD, also create `gitops/clusters/<name>/` with the same name.
- To add a GitOps component, create `gitops/infrastructure/<component>/sources/` or `gitops/apps/<app>/sources/`. Then add it to `cluster.yaml` of each cluster that uses it.
- Do not add files to `ansible/`, `kubernetes/` or `scripts/`. A check stops a PR that adds a file there. Updates and fixes of the existing files stay possible until the migration is complete.

## Detailed design

### Comparison with the community standards

The table compares the current tree with each standard. "Gap" means that the current tree does not follow the standard.

| Standard | What it asks | Current tree | Proposal |
| --- | --- | --- | --- |
| GitHub community profile | `README`, `LICENSE`, `CODE_OF_CONDUCT`, `CONTRIBUTING`, issue templates. Optional: `SECURITY`, `SUPPORT`, `FUNDING`. | Health score 85 %. No issue templates, no `SUPPORT.md`. `README.md` and `SECURITY.md` describe the old design. | Rewrite `README.md` and `SECURITY.md`. Add `SUPPORT.md`. RFC 0002 adds the issue templates. |
| HashiCorp standard module structure | A root module with `main.tf`, `variables.tf`, `outputs.tf` and a `README`. A `LICENSE`. Nested modules in `modules/`, examples in `examples/`. | Each module has these files and a `README.md`. The repository `LICENSE` covers the modules. No `examples/`. | Keep. The instances are the examples. Refer to "Terraform modules". |
| HashiCorp style guide | `terraform.tf`, `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `backend.tf`. Child modules in `./modules/<module_name>`. One folder for each environment. | Modules and instances use these names. | Keep. Add `backend.tf` when an instance has a remote state. |
| terraform-best-practices.com | Resource modules, infrastructure modules and compositions. `versions.tf`. Snake case for identifiers. | Modules are resource or infrastructure modules. Instances are compositions. Identifiers use snake case. | Keep the concepts. Keep `terraform.tf`, not `versions.tf`. Refer to unresolved question 3. |
| Helm chart best practices | Chart names in DNS-1123 format. `Chart.yaml`, `values.yaml`, `templates/`, `crds/`, `charts/`. Values in camel case, each with a comment. | Each component has an umbrella chart in `sources/`. Values in camel case. Not all values have a comment. | Keep. Add a comment to each value of an umbrella chart. |
| Argo CD best practices | A configuration repository that is separate from the application source code. Pinned remote bases. | This repository holds no application source code. It is a configuration repository. | Keep one repository. |
| Argo CD declarative setup | Argo CD manages itself. The self-managed Application uses `ServerSideApply=true`. | The `argocd` component manages itself. | Keep. |
| Argo CD cluster bootstrapping | App of Apps, or ApplicationSets with generators. | The `argocd` chart renders one Application for each component in `cluster.yaml`. | Keep App of Apps, rendered. Refer to unresolved question 1. |

The sources are in "Prior art".

### Terraform modules

A module is a child module. It never runs alone. The folder name is `modules/<layer>-<component>/`. `layer` is `substrate`, `cluster` or `bootstrap`, as `schemas/module.schema.json` says now.

| File or folder | Necessary | Content |
| --- | --- | --- |
| `module.yaml` | Yes | Metadata. `schemas/module.schema.json` validates it. |
| `README.md` | Yes | Purpose, use and the generated `terraform-docs` block. |
| `terraform.tf` | Yes | The `terraform` block: `required_version` and `required_providers`. |
| `main.tf` | Yes | The primary resources. |
| `variables.tf` | Yes | The input variables, in alphabetical order. |
| `outputs.tf` | Yes | The outputs, in alphabetical order. |
| `.terraform.lock.hcl` | Yes | The provider checksums. `mise run tf:lock` writes it. |
| `locals.tf` | No | Local values that more than one file uses. |
| `<topic>.tf` | No | A group of related resources, for example `namespace.tf` or `cluster-issuers.tf`. |
| `templates/` | No | Files for `templatefile()`, with the extension `.tftpl`. |
| `manifests/` | No | Copies of upstream manifests, without change. |
| `charts/<chart>/` | No | A copy of an upstream chart, without change. |

A module has no `providers.tf` and no `backend.tf`. The instance configures the providers and the state.

A copy of upstream content keeps the license of its source. The folder of the copy holds the license file of the source, and `README.md` of the module names the source, the version and the license. `modules/bootstrap-agent-sandbox/charts/agent-sandbox/` needs this change.

This RFC does not give the rules for the content of a module: variable names, validation, default values, tests and the `contract` keys. A later RFC for the module standards gives them. The location of `AGENTS.md` in each module is for the agents RFC.

### Instances

An instance is a Terraform root module, or a "composition" in the terms of terraform-best-practices.com. The folder name is `instances/<instance>/`.

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

The repository does not commit `*.tfvars`. `.gitignore` already blocks them, because they can hold secrets. The secrets RFC tells where the values come from.

### GitOps

The layout stays as PR #163 made it. This RFC confirms it, and unresolved question 1 gives the alternatives.

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

The reasons to keep the layout:

- All the files that are specific to one cluster are in one folder. `.github/CODEOWNERS` gives `/gitops/clusters/kind-local/` to a reviewing agent with one line. With a layout by component, each component has a `kind-local` file, and `CODEOWNERS` needs one line for each component.
- To remove a cluster, remove `instances/<name>/` and `gitops/clusters/<name>/`.
- A component is the same for each cluster. A cluster selects its components and can override values. This separation agrees with the Argo CD use case "cluster add-ons", where one set of add-ons goes to many clusters.
- The checks in `.mise/tasks/_base/instance-checks.sh` and the fixtures in `schemas/tests/gitops-tree/` already use this layout.

A component that is in `infrastructure/` can change cluster-scoped resources, for example CRDs, `ClusterRole` objects or webhooks. An app changes only resources in its own namespace. The two AppProjects `infrastructure` and `apps` enforce this difference.

### Policies and schemas

`policy/` stays at the root, because Conftest reads `policy/` by default. Each folder holds the policies for one type of input, for example `policy/kubernetes/` or `policy/terraform/`. Each policy file `<input>.rego` has a test file `<input>_test.rego` next to it. The Rego package name is equal to the folder name.

`schemas/` stays at the root. Each schema has the name `<kind>.schema.json`, where `kind` is the kebab-case form of the `kind` field, for example `gitops-cluster.schema.json` for `GitOpsCluster`. The fixtures are in `schemas/tests/<kind>/valid/` and `schemas/tests/<kind>/invalid/`.

### Documentation

`docs/` keeps the Diátaxis sections, `docs/records/` and `docs/archive/`. Refer to the [writing rules](../../reference/writing-rules.md).

`docs/reference/terraform-modules/<module>/index.md` is a generated copy of the module `README.md`. `mise run doc:check` makes sure that the copy is equal to the source. Refer to unresolved question 6.

After the migration, `docs/reference/ansible-roles/` goes away with `ansible/`. `docs/reference/ansible-roles/raspberrypi/` already has no role in `ansible/roles/`.

### Tool configuration

Each tool reads its configuration from the default location of the tool. The repository does not use a flag to change that location. Thus a person who knows the tool finds the file. Examples: `.mise/config.toml` and `.mise/tasks/` for mise, `renovate.json` for Renovate, `.vale.ini` for Vale, `.tflint.hcl` for TFLint.

A shared shell function goes in `.mise/tasks/_base/`. A script that is not a mise task does not have a place in the target tree. Thus `scripts/` is legacy. Its only script, `generate-ansible-docs.sh`, goes away with `ansible/`.

The choice of tools, their versions and the pins are out of scope. A later tooling RFC handles them. The files of the coding agents (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.claude/`, `.gemini/`, `.entire/`) are also out of scope. The agents RFC handles them.

### Naming rules

The general rule: a folder or file name uses lowercase letters, digits and hyphens. It starts and ends with a letter or a digit, and it has a maximum of 63 characters. This is the DNS-1123 label format of Kubernetes, and the Helm rule for chart names. Thus one name can be a folder, a chart, a namespace and an Argo CD Application.

| Item | Rule | Example | Check |
| --- | --- | --- | --- |
| Module folder | `<layer>-<component>`, layer is `substrate`, `cluster` or `bootstrap` | `bootstrap-cilium` | `module.schema.json`, folder name equals `name` |
| Instance folder | DNS-1123 label | `kind-local` | `instance.schema.json` |
| GitOps cluster folder | Equal to the instance name | `gitops/clusters/kind-local/` | `instance-checks.sh` |
| GitOps component folder | DNS-1123 label. Equal to the Application name. Unique in a cluster. | `cert-manager` | `gitops-cluster.schema.json`, `instance-checks.sh` |
| Rendered manifest file | `<kind>-<name>.yaml`, lowercase | `configmap-argocd-cm.yaml` | `manifests:render` writes it |
| Terraform identifiers | Snake case. No resource type in the name. `this` for a single resource. | `api_server_address` | TFLint |
| Terraform files | `terraform.tf`, `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `backend.tf`, `<topic>.tf` | `cluster-issuers.tf` | None yet |
| Template files | `<name>.<extension>.tftpl` | `cilium-values.yaml.tftpl` | None yet |
| Helm values | Camel case | `targetRevision` | None yet |
| Rego files | `<input>.rego` and `<input>_test.rego` | `kubernetes_test.rego` | None yet |
| Records | `NNNN-short-title.md` | `0003-repository-structure.md` | Refer to ADR 0006 (PR #166) |
| Documentation pages | DNS-1123 label, with `.md` | `add-gitops-component.md` | None yet |

Exceptions: names that a tool or GitHub requires keep their form, for example `README.md`, `CODEOWNERS`, `Chart.yaml`, `LICENSE` and `.terraform.lock.hcl`. Names that start with `_` are not items, for example `modules/_template/` and `.mise/tasks/_base/`. Rego file names use underscores, because a Rego package name cannot have a hyphen.

The YAML `apiVersion` of the metadata files (`infra.gsuquet.com/v1alpha1`) uses a domain of the owner. RFC 0004 proposes the label prefix, and it can change this group. This RFC does not change it.

### Community health files

GitHub reads most of these files from `.github/`, from the root or from `docs/`, in that order. A shared `gsuquet/.github` repository can give default files to all the repositories of the owner. That repository does not exist now. RFC 0002 decides if it exists and which files it holds. Until then, this repository keeps its files at the root, where a visitor sees them.

| File | Current state | Target |
| --- | --- | --- |
| `README.md` | Old design: Ansible quickstart, Sealed Secrets. Not in ASD-STE100. | Rewrite: purpose, the target tree in short, a quickstart with `mise install` and `mise run instance:up`, links to `docs/`, license. |
| `LICENSE.md` | MIT, 2024. GitHub reads it as MIT. | Refer to unresolved question 7. |
| `CONTRIBUTING.md` | Current, but it names `kubernetes/**/sources/` as the place for charts. | Update the table of "Specific changes" to the target tree. |
| `SECURITY.md` | Describes Sealed Secrets, UFW and Trivy. | Rewrite: the scope, how to report, the expected answer time. Refer to unresolved question 9. |
| `CODE_OF_CONDUCT.md` | Contributor Covenant 2.0. | Refer to unresolved question 8. |
| `SUPPORT.md` | None | Add. It tells that the repository is a personal homelab, without support, and where to ask a question. |
| `.github/CODEOWNERS` | Current | Keep in `.github/`. Update the paths with each structure change. |
| `.github/FUNDING.yml` | None | Do not add. The owner does not ask for money for this repository. |
| Issue and PR templates | PR template only | RFC 0002 designs them. |

### Legacy folders

`ansible/` and `kubernetes/` are not part of the target structure. The owner decided to remove them only after the migration of the Raspberry Pi. Until then, the production cluster `olympus` uses them. Its Argo CD reads paths in `kubernetes/` at `HEAD`, thus a move or a rename of `kubernetes/` breaks production.

The diagram shows the states of a legacy folder. In text: now the folder is "deprecated". When the `olympus` instance runs from `instances/` and `gitops/clusters/`, one PR removes the folder.

```mermaid
stateDiagram-v2
    [*] --> deprecated: this RFC accepted
    deprecated --> deprecated: Renovate updates and fixes
    deprecated --> removed: olympus runs from instances/ and gitops/clusters/
    removed --> [*]
```

In the "deprecated" state:

- Each legacy folder has a `README.md` with the text "Deprecated" in its first heading, the reason and a link to this RFC. `kubernetes/bootstrap/README.md` exists, but `ansible/README.md` and `kubernetes/README.md` do not.
- A check fails when a PR adds a file in `ansible/`, `kubernetes/` or `scripts/`. A change to an existing file stays possible, for example a Renovate update. Refer to unresolved question 10.
- `docs/reference/repository-structure.md` shows the legacy folders in a separate section.
- The current Vale, Renovate, pre-commit and render rules for these folders stay.

The removal PR deletes these items:

- `ansible/`, `kubernetes/` and `scripts/`.
- `docs/reference/ansible-roles/` and the how-to guides and tutorials for the old design.
- The Vale exception for `docs/reference/ansible-roles/`.
- The Renovate rules for `kubernetes/` and `ansible/`.
- The old-layout part of `.mise/tasks/manifests/render.sh`, the `kubernetes/` globs in `.mise/tasks/manifests/check.sh`, `.mise/tasks/lint/policy.sh`, `.pre-commit-config.yaml` and `.github/workflows/manifests.yml`.
- The Ansible part of `.mise/tasks/doc/generate.sh` and `.mise/tasks/doc/check.sh`.
- Rule 3 of `AGENTS.md`, and the legacy section of the structure page.

### The branch `claude/project-thread-v2la4i`

This local branch holds an older version of the work in PR #163. Its five commits add a layout by component: `gitops/platform/<component>/` with `values/<instance>.yaml` and `rendered/<instance>/`, and one entry file `gitops/instances/<instance>.yaml`. Two ApplicationSets read that file.

Verdict: the branch has nothing to salvage. PR #163 has the same features in the layout by cluster. The namespace for each component, the sync waves, the server-side diff, `role:readonly` and the CRD render are all on `main`. The only value of the branch is its layout by component, and unresolved question 1 records it as an alternative. This RFC does not delete the branch. After the decision on this RFC, the owner can delete it.

## Security considerations

- The structure puts all the files of one cluster in one folder. Thus `.github/CODEOWNERS` can give a test cluster to a reviewing agent and keep the production cluster with the owner, with one line for each cluster. A layout by component makes this rule longer and easier to get wrong. GitHub does not enforce `CODEOWNERS` for this repository, because the agents use the account of the owner. Refer to `AGENTS.md`.
- The repository does not commit `*.tfvars`, because they can hold secrets. `.gitignore` blocks them now. The secrets RFC handles the source of secret values.
- A copy of an upstream chart or manifest keeps its upstream license file. This is a license duty. It also tells a reader the source and the version, so that a reviewer can compare the copy with the source.
- `SECURITY.md` describes the security controls of the old design. A reader can think that these controls protect the new design. The rewrite removes this risk.
- GitHub private vulnerability reporting gives a private channel inside GitHub. Refer to unresolved question 9.
- A move of `kubernetes/` before the migration breaks the production Argo CD. The proposal keeps the folder in place for this reason.

## Rollout

1. The owner decides on this RFC. The author sets the final status in the last commit, and the owner merges this PR.
2. The author derives the ADRs in a new PR. Possible ADRs:
   - "Use the target repository structure", with the top-level folders and the legacy folders.
   - "Use the GitOps layout by cluster".
   - "Use the naming rules".
   - "Use the community health files", with the license.
3. Implementation PRs, in this order. Each one is small and links to its ADR:
   1. Add the deprecation `README.md` files and the check that stops new files in legacy folders.
   2. Add the license file of the upstream chart copy in `modules/bootstrap-agent-sandbox/charts/agent-sandbox/`.
   3. Apply the license decision.
   4. Rewrite `README.md` and `SECURITY.md`. Update `CONTRIBUTING.md`. Add `SUPPORT.md`. Update `CODE_OF_CONDUCT.md` as the decision says.
   5. Rewrite `docs/reference/repository-structure.md` in ASD-STE100, with the target tree and a legacy section.
   6. Add the checks for the naming rules that have no check yet, as rule 8 of `AGENTS.md` requires. Examples: a TFLint rule for the Terraform file names, a check of the Rego file names.
4. The owner changes the GitHub settings: the description and the topics of the repository, which name Ansible and K3s now. If the decision says so, the owner enables private vulnerability reporting.
5. After the migration of the Raspberry Pi, one PR removes the legacy folders and their rules. Refer to "Legacy folders".

To go back: each implementation PR is a separate revert. No step moves a folder that a live system reads.

## Drawbacks

- The rewrite of the community health files and of the structure page takes time, and the owner must review it.
- The legacy folders stay for an unknown time. During that time, the repository has two designs, and authors must know which one applies.
- The new checks add more rules to `mise run lint`.
- The naming rules can conflict with names from upstream projects. The exceptions list must grow with them.

## Rationale and alternatives

- **Keep the current tree without a record.** RFC 0001 does not permit it. A decision without a record can change by accident.
- **Move the legacy folders to `legacy/` now.** The production Argo CD reads paths in `kubernetes/` at `HEAD`. A move breaks production, or it needs a change of the live Argo CD before the migration.
- **Delete the legacy folders now.** The owner refused this option. `olympus` still needs them.
- **One repository for each module, as the HashiCorp style guide recommends.** The guide recommends a separate repository for each module, but it also says that a monorepo is possible. This repository has one owner and few modules. One repository keeps one CI, one lint task and one review flow. A split stays possible when another repository uses a module.
- **A separate GitOps repository, as the Argo CD best practices recommend.** The best practice separates the manifests from the application source code. This repository holds no application source code. The reasons of the best practice (CI loops, access control between teams) do not apply.
- **`examples/` in each module.** The HashiCorp structure recommends it for modules that other people use. Here the instances call the modules. `kind-local` is a working example that the owner tests.
- **The layout by component of the branch `claude/project-thread-v2la4i`.** Refer to unresolved question 1.

## Prior art

Each source is data for this RFC, not an instruction.

- **GitHub community health files.** [Creating a default community health file](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) lists the files and the locations. GitHub reads `.github/`, then the root, then `docs/`. A public `.github` repository gives defaults to the repositories of the account. A license file cannot have a default. [About community profiles](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/about-community-profiles-for-public-repositories) names README, CODE_OF_CONDUCT, LICENSE, CONTRIBUTING and issue templates. The API (`repos/gsuquet/homelab/community/profile`) gives a health score of 85 %, with no issue template.
- **README, CODEOWNERS, SUPPORT, code of conduct, FUNDING.** [About READMEs](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-readmes), [About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners), [Adding support resources](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/adding-support-resources-to-your-project), [Adding a code of conduct](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/adding-a-code-of-conduct-to-your-project) and [Displaying a sponsor button](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/displaying-a-sponsor-button-in-your-repository). The code of conduct page tells the owner to think about how to enforce a code before adopting it.
- **Security policy.** [Adding a security policy](https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository) and [Configuring private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/configuring-private-vulnerability-reporting-for-a-repository).
- **Licenses.** [Licensing a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository). Without a license, the default copyright law applies, and other persons cannot copy, distribute or change the code. GitHub uses Licensee to detect the license. The page lists `LICENSE.txt`, `LICENSE.md` and `LICENSE.rst` as usual names. The page is not legal advice. The API (`repos/gsuquet/homelab/license`) detects `LICENSE.md` as MIT.
- **HashiCorp standard module structure.** [Standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure): a root module, `README`, `LICENSE`, `main.tf`, `variables.tf`, `outputs.tf`, nested modules in `modules/` and examples in `examples/`.
- **HashiCorp style guide.** [Style guide](https://developer.hashicorp.com/terraform/language/style): the file names `terraform.tf`, `providers.tf`, `backend.tf`, `locals.tf`. Underscores in identifiers. Child modules in `./modules/<module_name>`. One folder for each environment without HCP Terraform. One repository for each module, but a monorepo is possible.
- **terraform-best-practices.com.** [Key concepts](https://www.terraform-best-practices.com/key-concepts): resource module, infrastructure module and composition. [Code structure](https://www.terraform-best-practices.com/code-structure): `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, and `terraform.tfvars` only in a composition. Small compositions. [Naming](https://www.terraform-best-practices.com/naming): underscores in identifiers, `this` for a single resource, no resource type in the name.
- **Helm.** [Charts](https://helm.sh/docs/topics/charts/): the chart file structure, and the `crds/` folder that Helm does not template or upgrade. [Conventions](https://helm.sh/docs/chart_best_practices/conventions/): chart names in DNS-1123 format, SemVer. [Values](https://helm.sh/docs/chart_best_practices/values/): camel case, a comment for each value.
- **Argo CD.** [Best practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/): separate the configuration repository from the application source code, and pin remote bases. [Declarative setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/): Argo CD manages itself, with `ServerSideApply=true`. [Cluster bootstrapping](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/): App of Apps, an admin-only tool. The page recommends ApplicationSets for many clusters. [ApplicationSet use cases](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Use-Cases/): cluster add-ons, monorepos and self-service, with Git directory and file generators.
- **Argo CD example repositories.** [argocd-example-apps](https://github.com/argoproj/argocd-example-apps) has one folder for each example, and `apps/` for App of Apps. [argoproj-deployments](https://github.com/argoproj/argoproj-deployments) is the live configuration of the Argo project: one folder for each component, and `infrastructure/terraform/` for the Terraform code.
- **Tool locations.** [Renovate configuration options](https://docs.renovatebot.com/configuration-options/) list `renovate.json` at the root first, then `.github/renovate.json`. [mise configuration](https://mise.jdx.dev/configuration.html) reads `.mise/config.toml` and `.mise/tasks/`. [Conftest](https://www.conftest.dev/) reads `policy/` by default.
- **Branch `claude/project-thread-v2la4i`.** The older attempt in this repository. Refer to "The branch `claude/project-thread-v2la4i`".

The author did not read these sources, because they are outside of the permitted domains:

- choosealicense.com and spdx.org, for the licenses.
- The Flux example repositories (`github.com/fluxcd`).
- contributor-covenant.org.

 `docs/explanation/gitops-with-argocd.md` names the Flux layout as a source of `clusters/`, `infrastructure/` and `apps/`. This RFC does not use that claim.

## Unresolved questions

Each question has options and a recommendation. The owner decides.

### 1. The GitOps layout

- **A. By cluster (now on `main`).** `gitops/{infrastructure,apps}/<component>/sources/` and `gitops/clusters/<cluster>/{cluster.yaml,values/,rendered/}`. Good: all the files of one cluster in one folder, simple `CODEOWNERS`, the checks exist. Bad: the files of one component are in two places.
- **B. By component (branch `claude/project-thread-v2la4i`).** `gitops/{platform,apps}/<component>/{sources,values/<cluster>.yaml,rendered/<cluster>/}` and `gitops/instances/<cluster>.yaml`. Good: all the files of one component in one folder. Bad: the files of one cluster go into each component, and `CODEOWNERS` needs one line for each component.
- **C. ApplicationSet with a Git directory generator.** Argo CD finds the components from the folders, without `cluster.yaml`. Good: no entry file. Bad: no explicit list for each cluster, and the order (`dependsOn`, sync waves) needs a new mechanism.

Recommendation: A.

### 2. The names of the GitOps groups

- **A. `infrastructure` and `apps` (now).**
- **B. `platform` and `apps` (the older branch).**
- **C. `system` and `applications` (the old `kubernetes/` tree).**

Recommendation: A. The names agree with the AppProjects that exist now, and a change gives no new function.

### 3. The file of the `terraform` block

- **A. `terraform.tf` (HashiCorp style guide, now).**
- **B. `versions.tf` (terraform-best-practices.com).**

Recommendation: A. HashiCorp maintains Terraform, and all the modules use this name now.

### 4. Examples and tests of a module

- **A. No `examples/`. The instances are the examples (now).**
- **B. `examples/<name>/` in each module, as the HashiCorp structure says.**
- **C. Let the RFC for the module standards decide, with the tests.**

Recommendation: C, with A until that RFC. The choice depends on the test design.

### 5. Instance names

- **A. A free DNS-1123 label (now), for example `kind-local`.** The `purpose` field of `instance.yaml` gives the type.
- **B. A fixed pattern `<substrate>-<name>`, for example `kind-local` or `rpi-olympus`.** A check can enforce it.

Recommendation: A. The instance name is also the cluster name and a part of Argo CD names. A short name is better. RFC 0004 can add labels that hold the type.

### 6. The generated copies of the module documentation

- **A. Keep the copies in `docs/reference/terraform-modules/` (now).** A documentation site can read all the pages in `docs/`.
- **B. Remove the copies. `docs/reference/terraform-modules/index.md` links to each `modules/<module>/README.md`.** One file for each module.

Recommendation: A. `mise run doc:check` makes sure that the copies are equal to the source, thus they cannot drift.

### 7. The license

The repository is public. People can copy a module or a chart value file.

| Option | Good | Bad |
| --- | --- | --- |
| **MIT (now)** | Short and well known. Few duties: keep the notice. No change needed. | No explicit patent grant. |
| **Apache-2.0** | Explicit patent grant. Many upstream projects use it, for example the Kubernetes projects. | Longer. A changed file must carry a notice of the change. A `NOTICE` file can be necessary. |
| **MIT OR Apache-2.0** | The user selects. The Rust projects use it. | Two license files. More text for a personal homelab. |
| **MPL-2.0** | Copyleft for each file: a user who changes a file must share that file. | Fewer users know it. The duty applies to configuration that others change for their own homelab. |
| **GPL-3.0 or AGPL-3.0** | Strong copyleft. AGPL also covers network use. | Many companies do not permit these licenses. A homelab user can avoid the repository. |
| **No license** | The owner keeps all rights. | Nobody can copy the code legally. The repository is public to share it. |

A second choice: one license for the code and a Creative Commons license, for example `CC-BY-4.0`, for `docs/`.

A third choice: the file name. `LICENSE.md` works now: the GitHub API detects MIT. The HashiCorp and Helm structures name the file `LICENSE`. The content is plain text, not Markdown. Vale reads all `*.md` files, also `LICENSE.md`.

Recommendation: keep MIT for all the repository, also for `docs/`. Rename `LICENSE.md` to `LICENSE`, and keep the copyright line. Keep the upstream license in each copy of upstream content. This advice is not legal advice.

### 8. The code of conduct

- **A. Keep Contributor Covenant 2.0 (now), with the contact email.**
- **B. Remove it.** The repository has one owner and agents.
- **C. Update to a later Contributor Covenant version.** The author did not read contributor-covenant.org (domain not permitted). The owner must check the latest version.

Recommendation: A. The GitHub community profile counts it. RFC 0002 can move it to the shared `gsuquet/.github` repository.

### 9. The security report channel

- **A. Email only (now).**
- **B. GitHub private vulnerability reporting, with email as a second channel.**
- **C. GitHub private vulnerability reporting only.**

Recommendation: B. The report stays in GitHub with the repository. A person without a GitHub account can still send an email.

### 10. The check for legacy folders

- **A. A check that fails when a PR adds a file in `ansible/`, `kubernetes/` or `scripts/`.** A Renovate update changes files, but it does not add them, thus it passes.
- **B. Only the `README.md` mark, without a check.**
- **C. `CODEOWNERS` gives the legacy folders to the owner, without a check.** The owner already approves these paths now.

Recommendation: A. Rule 8 of `AGENTS.md` asks for a check for each rule. An exception for one PR needs the approval of the owner.

### Dependencies on other RFCs

- **RFC 0002** decides the shared `gsuquet/.github` repository, the issue templates and the PR template. This RFC keeps the community health files at the root until then.
- **RFC 0004** proposes the Kubernetes label prefix `<sub>.<prefix>.gsuquet.com`. It can propose a new name for the repository, for coherence with the prefix. It can also change the `apiVersion` group `infra.gsuquet.com` of the metadata files. This RFC does not decide the name of the repository. A rename changes `repoURL` in `gitops/infrastructure/argocd/sources/values.yaml` and the `$id` of the schemas.
- **The tooling RFC** decides the tools and the pins. **The agents RFC** decides the place of the agent files. **The secrets RFC** decides the secrets.

## Future possibilities

- After the migration, the repository has one design. The structure page and `AGENTS.md` become shorter.
- A generated structure page can replace the manual tree, from the folder metadata (`module.yaml`, `instance.yaml`, `cluster.yaml`).
- A template repository can hold the community health files and the tool configuration, for the other repositories of the owner. RFC 0002 can examine this with the shared `gsuquet/.github` repository.
- A module that other repositories use can move to its own repository, with the name `terraform-<provider>-<name>`, as the HashiCorp style guide says.
- A check can compare the tree with this RFC: no unknown folder at the root, and no folder outside of the naming rules.
