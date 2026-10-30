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

1. Scans `modules/` for module directories (one level deep). It skips `modules/_template/`.
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
[INFO] Generating docs for module: cluster-kind
[INFO] ✓ cluster-kind → /path/to/modules/cluster-kind/README.md

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

### `lint`

**Script**: `.mise/tasks/lint/_default.sh`
**Description**: Run every linter and check. The `Lint` workflow and the pre-commit hooks run the same tasks.

It runs these tasks:

| Task | Tools | Checks |
| --- | --- | --- |
| `lint:terraform` | `terraform fmt`, TFLint | Format of all `.tf` files. TFLint with the `all` preset of the bundled `terraform` ruleset (`.tflint.hcl`), in each Terraform directory. |
| `lint:policy` | Conftest | Runs the policy unit tests (`conftest verify`), then checks Terraform, Kubernetes, pre-commit and mise files against the policies in `policy/`. Refer to [Policies](policies.md). |
| `lint:actions` | actionlint, zizmor | Syntax and security of the workflows in `.github/workflows/`. |
| `lint:shell` | ShellCheck, shfmt | Shell scripts tracked by git. shfmt reads its settings from `.editorconfig`. |
| `lint:docs` | Vale | Markdown files against the ASD-STE100 rules. Only errors fail the check. Refer to [Writing rules](writing-rules.md). |
| `schemas:test` | check-jsonschema | Refer to [Schemas](schemas.md). |
| `schemas:check` | check-jsonschema, yq | Refer to [Schemas](schemas.md). |

**Usage**:

```bash
mise run lint
mise run lint:terraform
```

---

### `instance:plan`, `instance:up`, `instance:down`

**Scripts**: `.mise/tasks/instance/plan.sh`, `up.sh`, `down.sh`
**Description**: Show the changes, create or update, or destroy one instance in `instances/`.

Each task does these steps:

1. Validates `instances/<instance>/instance.yaml` against `schemas/instance.schema.json`.
2. If the instance uses `cluster-kind`, makes sure that the `kind` command is installed and that Docker runs. If Docker does not run, the task starts the first runtime that it finds: Colima, OrbStack, Rancher Desktop or Docker Desktop (macOS). To start a specific runtime, set `DOCKER_RUNTIME` to `colima`, `orbstack`, `rancher-desktop` or `docker-desktop`. Set `DOCKER_NO_START=1` to stop with an error instead. If the `docker` command is missing, the task stops with an error. If image pulls fail behind a company proxy, refer to [Use Kind behind a TLS-inspecting proxy](../how-to/use-kind-behind-a-tls-proxy.md).
3. Runs `terraform init` in `instances/<instance>/`.
4. Runs `terraform plan`, `terraform apply` or `terraform destroy`.

`instance:up` applies the modules of the `cluster` layer first, with `-target`. Then it applies all the layers. The providers of the other layers use the outputs of the cluster. If a change replaces the cluster, these outputs are not known during one full plan, and the plan fails. `instance:plan` makes one full plan, thus it can fail when a change replaces the cluster. In that case, use `instance:up`.

For an instance that uses `cluster-kind`:

- After the apply, `instance:up` runs `kind export kubeconfig`. kind adds the cluster, the user and the context `kind-<cluster>` to `~/.kube/config`, or to the first file in `KUBECONFIG`. kind changes no other entry. The new context becomes the current context.
- After the destroy, `instance:down` removes the cluster, the user and the context `kind-<cluster>` from the kubeconfig. It removes no other entry. If `kind-<cluster>` was the current context, no context is current after the task.
- Terraform also writes the kubeconfig of the cluster to `~/.kube/kind-<cluster>`.

For a `test` or `demo` instance, `instance:up` and `instance:down` do not ask for approval. For a `production` instance, Terraform asks you to type `yes` for each apply that has changes.

**Usage**:

```bash
mise run instance:plan kind-local
mise run instance:up kind-local
mise run instance:down kind-local
```

---

### `tf:lock`

**Script**: `.mise/tasks/tf/lock.sh`
**Description**: Update the Terraform lock files for all supported platforms.

Run it after you change a provider version. Commit the `.terraform.lock.hcl` files.

---

### `manifests:validate`

**Script**: `.mise/tasks/manifests/validate.sh`
**Description**: Validate the rendered manifests against the Kubernetes schemas with kubeconform.
