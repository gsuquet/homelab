# Reference: Mise Tasks

Tasks are defined under `.mise/tasks/` and run with `mise run <task>`. All tasks operate on the Kubernetes manifests in this repository.

---

## Available Tasks

### `manifests:render`

**Script**: `.mise/tasks/manifests/render.sh`
**Description**: Render Kubernetes manifests from Helm charts

**What it does**:

1. Scans the repository for all `**/sources/Chart.yaml` files
2. For each chart found:
   - Runs `helm dependency update` to fetch or update chart dependencies (downloads the upstream chart)
   - Runs `helm template <component> <source_dir> -f values.yaml` to produce `manifests/install.yaml`
   - Splits `manifests/install.yaml` into individual files, one per Kubernetes resource, using `# Source:` comment markers
   - Trims leading and trailing YAML document separators (`---`) from each split file
   - Resolves filename conflicts by appending a numeric suffix
3. Regenerates `kustomization.yaml` to list all split manifest files
4. Prints a summary of charts processed and any errors

**When to use**: After changing a `sources/Chart.yaml` or `sources/values.yaml` file. The pre-commit hook also runs this task automatically when those files are staged.

**Usage**:

```bash
mise run manifests:render
```

**Example output**:

```bash
Rendering argo-cd...
  Updating dependencies...
  Rendering template...
  Splitting manifests...
  Generated 47 manifest files
Done: 1 rendered, 0 errors
```

**Dependencies**: `helm` (version from `.mise/config.toml`)

---

### `manifests:check`

**Script**: `.mise/tasks/manifests/check.sh`
**Description**: Check if manifests are up-to-date

**What it does**:

1. Records the current git diff state of `kubernetes/**/manifests/`
2. Runs `mise run manifests:render`
3. Checks if the `kubernetes/**/manifests/` files changed as a result
4. Exits with code `0` if manifests are current (no changes), or code `1` if they are out of date

**When to use**:

- In CI to validate that a pull request has committed up-to-date manifests
- Locally to verify your working tree is clean before pushing

**Usage**:

```bash
mise run manifests:check
```

**Exit codes**:

| Code | Meaning |
| ---- | ------- |
| 0 | Manifests are current |
| 1 | Manifests are out of date — run `mise run manifests:render` and commit |

**Dependencies**: `manifests:render`

---

## Pre-commit Hook Integration

The `render-manifests` pre-commit hook (defined in `.pre-commit-config.yaml`) calls `mise run manifests:render` automatically before commits that stage any `kubernetes/**/sources/*.yaml` file. This ensures the rendered manifests are always included in the same commit as the source changes.

To install the hooks:

```bash
pre-commit install
```

---

### `tf:docs`

**Script**: `.mise/tasks/tf/docs.sh`
**Description**: Generate reference documentation for all Terraform modules

**What it does**:

1. Scans `terraform/modules/` for module directories (one level deep)
2. For each module, runs `terraform-docs markdown table --output-mode inject` to inject
   a Markdown table of inputs, outputs, providers, and requirements into the module's
   `README.md` between `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->` markers
3. Creates `README.md` if it does not already exist
4. Prints a summary of modules processed and any errors

**When to use**: After adding or modifying variables, outputs, or provider requirements
in any Terraform module. Also useful when adding a new module to the repository.

**Usage**:

```bash
mise run tf:docs
```

**Example output**:

```bash
[INFO] Generating docs for module: kind-cluster
[INFO] ✓ kind-cluster → /path/to/terraform/modules/kind-cluster/README.md

[INFO] ====================================
[INFO] Documentation generation complete!
[INFO] Modules processed: 1
[INFO] ====================================
```

**Dependencies**: [`terraform-docs`](https://terraform-docs.io/) — install with `brew install terraform-docs`

---

### `doc:generate`

**Script**: `.mise/tasks/doc/generate.sh`
**Description**: Generate reference documentation for Terraform modules and Ansible roles

**What it does**:

1. Runs `mise run tf:docs` to auto-generate Terraform module READMEs
2. Syncs module READMEs to `docs/reference/terraform-modules/<module>/index.md`
3. Executes `scripts/generate-ansible-docs.sh` to extract tasks and default variables from Ansible roles and inject them into `docs/reference/ansible-roles/<role>/index.md`

**Usage**:

```bash
mise run doc:generate
```

---

### `doc:check`

**Script**: `.mise/tasks/doc/check.sh`
**Description**: Verify that generated Ansible and Terraform documentation is up to date

**Usage**:

```bash
mise run doc:check
```

---

### `changelog:generate`

**Script**: `.mise/tasks/changelog/generate.sh`
**Description**: Generate or update `CHANGELOG.md` using `git-cliff` based on conventional commit history

**Usage**:

```bash
mise run changelog:generate
```

---

### `pr:create`

**Script**: `.mise/tasks/pr/create.sh`
**Description**: Helper script for PR creation using GitHub CLI (`gh`)

**Usage**:

```bash
mise run pr:create
```
