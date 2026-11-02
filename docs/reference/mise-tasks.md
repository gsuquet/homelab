# Mise tasks

The tasks of the repository are file tasks in `.mise/tasks/`. `mise run <task>` runs a task. Each task script starts with `set -euo pipefail`.

mise makes the name of a task from the path of its file below `.mise/tasks/`. The folder is the namespace, and the file name without `.sh` is the name: `.mise/tasks/lint/docs.sh` is `lint:docs`. A file with the name `_default.sh` has the name of its folder: `.mise/tasks/lint/_default.sh` is `lint`. mise lists only the executable files as tasks ([mise: file tasks](https://mise.jdx.dev/tasks/file-tasks.html)).

The files in `.mise/tasks/_base/` are not executable, so they are not tasks. The tasks load them with `source`:

| File | Content |
| --- | --- |
| `_base/log.sh` | `log_info`, `log_warn` and `log_error`. They print `[INFO]`, `[WARN]` or `[ERROR]` before the message. |
| `_base/instance.sh` | The shared functions of the instance tasks. |
| `_base/instance-checks.sh` | The checks of the instance folders and of the `gitops/` tree. `schemas:check` and `schemas:test` use them. |

`.mise/config.toml` defines no task. It sets the tools, the environment variables and the settings. Refer to [Tools](tools.md).

| Task | Script | Description |
| --- | --- | --- |
| `changelog:generate` | `changelog/generate.sh` | Write `CHANGELOG.md` from the Git history. |
| `doc:check` | `doc/check.sh` | Check that the generated module docs are current. |
| `doc:generate` | `doc/generate.sh` | Generate the module docs, and copy them to `docs/reference/terraform-modules/`. |
| `instance:plan`, `instance:up`, `instance:down` | `instance/plan.sh`, `up.sh`, `down.sh` | Run Terraform on one instance. Refer to [Instance tasks](instance-tasks.md). |
| `labels:sync` | `labels/sync.sh` | Make the GitHub labels of the repository equal to `.github/labels.yml`. |
| `lint` | `lint/_default.sh` | Run all the `lint:*` and `schemas:*` tasks. |
| `lint:actions` | `lint/actions.sh` | Check the GitHub Actions workflows. |
| `lint:docs` | `lint/docs.sh` | Check the Markdown files with Vale. |
| `lint:policy` | `lint/policy.sh` | Test the Conftest policies, then check the repository against them. |
| `lint:records` | `lint/records.sh` | Refuse references to the old proposal and decision record files. |
| `lint:records-test` | `lint/records-test.sh` | Test the exit status of `lint:records`. |
| `lint:shell` | `lint/shell.sh` | Check the shell scripts with ShellCheck and shfmt. |
| `lint:terraform` | `lint/terraform.sh` | Check the format of the Terraform files, and run TFLint. |
| `manifests:check` | `manifests/check.sh` | Check that the rendered manifests are current. |
| `manifests:render` | `manifests/render.sh` | Render the Helm charts to plain manifests. |
| `manifests:validate` | `manifests/validate.sh` | Validate the rendered manifests against the Kubernetes schemas. |
| `schemas:check` | `schemas/check.sh` | Validate the `module.yaml`, `instance.yaml` and `cluster.yaml` files, and the `gitops/` tree. |
| `schemas:test` | `schemas/test.sh` | Test the JSON schemas and the checks against their fixtures. |
| `tf:docs` | `tf/docs.sh` | Write the terraform-docs tables into the `README.md` of each module. |
| `tf:lock` | `tf/lock.sh` | Update the Terraform lock files for all the supported platforms. |

## Syntax

```bash
mise run <task> [<flag>...]
```

Only `labels:sync` and the instance tasks take arguments. The other tasks take no argument and no flag.

## `changelog`

### `changelog:generate`

The task runs `git-cliff -o CHANGELOG.md`. The repository has no git-cliff configuration file.

If the `git-cliff` command is missing, the task prints a warning. It then writes a `CHANGELOG.md` with the last 50 commits of `git log --oneline`.

No hook or workflow runs this task.

## `doc`

### `doc:generate`

1. The task runs `tf:docs`.
2. For each folder in `modules/`, except `modules/_template/`, the task copies `README.md` to `docs/reference/terraform-modules/<module>/index.md`.

The `generate-docs` pre-commit hook runs the task on a commit that changes a file in `modules/`. The hook then stages `docs/reference/terraform-modules` and `modules`.

### `doc:check`

The task runs `doc:generate`. Then it fails if `git diff` shows a change in `docs/reference/terraform-modules` or `modules`. It prints the changed files.

| Status | Condition |
| --- | --- |
| `0` | `[INFO] ✓ Documentation is up to date.` |
| `1` | `Documentation is out of date! Run 'mise run doc:generate' and commit the changes.` |

No hook or workflow runs this task.

## `instance`

The instance tasks are `instance:plan`, `instance:up` and `instance:down`. Their arguments, steps, environment variables and exit status are in [Instance tasks](instance-tasks.md).

## `labels`

### `labels:sync`

The task makes the GitHub labels of `gsuquet/homelab` equal to `.github/labels.yml`. It always passes `--repo gsuquet/homelab` to `gh`, and never reads the Git remotes.

```bash
mise run labels:sync [--dry-run] [--prune] [--yes]
```

| Flag | Effect |
| --- | --- |
| `--dry-run` | Print each `gh label create` and `gh label delete` command, with no write. The task still reads the labels of the repository, so it needs a `gh` login and network access. |
| `--prune` | Also delete each label of the repository that is not in the file. The task prints the labels, then asks `[y/N]`. |
| `--yes` | With `--prune`, delete with no question. Without `--prune`, the task prints a warning. |

The task does these steps in this order:

1. With `--prune` and without `--dry-run` or `--yes`, if the input is not a terminal, stop with an error.
2. Check the file. Each label has a name, a color of 6 hex digits with no `#`, and a description of 100 characters or fewer. No two names are equal, with no difference between uppercase and lowercase. The file has one or more labels.
3. Read the labels of the repository with `gh label list --limit 1000`.
4. For each label of the file, run `gh label create <name> --color <color> --description <description> --force`. This creates the label, or updates its color and description.
5. With `--prune`, find the labels of the repository that are not in the file. Ask `[y/N]`, unless `--dry-run` or `--yes`. An answer other than `y` or `Y` deletes no label, and the task exits with `0`.
6. Delete each of these labels with `gh label delete <name> --yes`.

A deleted label goes away from each issue and PR that has it. The `gh` login needs write access to the issues of the repository. No hook or workflow runs this task. The labels are in [Work rules](how-we-work.md).

| Status | Condition |
| --- | --- |
| `0` | `[INFO] ✓ Done.`, or `No label deleted.` |
| `1` | An error in the file, `--prune needs a terminal for the y/N question, or the --yes flag.`, or `Cannot list the labels of gsuquet/homelab.` |

## `lint`

### `lint`

The task runs these tasks as dependencies, then prints `✓ All linters and checks passed.`:

`lint:terraform`, `lint:policy`, `lint:actions`, `lint:shell`, `lint:docs`, `lint:records`, `lint:records-test`, `schemas:test`, `schemas:check`.

The `Lint` workflow runs `mise run lint` on each pull request and on each push to `main`. A `lint-*` pre-commit hook runs each `lint:*` task, except `lint:records-test`.

### `lint:actions`

1. Run `actionlint`.
2. Run `zizmor --offline --no-progress .github/workflows`.

The `lint-actions` pre-commit hook runs the task on a change in `.github/workflows/`.

### `lint:docs`

The task runs `vale --no-wrap --minAlertLevel=error` on each Markdown file that Git tracks. Only errors fail the check. `.vale.ini` sets the styles. Refer to [Writing rules](writing-rules.md#vale).

The `lint-docs` pre-commit hook runs the task on a change to a `.md` file or to a `.vale*` file.

### `lint:policy`

The task runs `conftest verify`, then `conftest test` for each policy namespace. The inputs and the rules are in [Policies](policies.md).

The `lint-policy` pre-commit hook runs the task on a change in `policy/`, to a `.tf`, `.yaml` or `.yml` file, or to `.mise/config.toml`.

### `lint:records`

The task runs `git grep -n -I -P` on the files that Git tracks, except `CHANGELOG.md`. It searches for three kinds of reference. The patterns are in `.mise/tasks/lint/records.sh`.

| Kind | Matches |
| --- | --- |
| A proposal number | The abbreviation of a proposal, then a number of four digits that starts with `0`. An IETF reference, for example `RFC 1123`, does not match. |
| A decision record | The abbreviation of a decision record, as one word. |
| An old folder | The old folders of the proposals and the decision records. |

| Status | Condition |
| --- | --- |
| `0` | `git grep` exits with `1`: no match. |
| `1` | `git grep` exits with `0`: a match. The task prints each match. |
| Other | `git grep` fails, for example with no PCRE support. The task exits with the status of `git grep`. |

The `lint-records` pre-commit hook runs the task on each commit.

### `lint:records-test`

The task puts a fake `git` first in `PATH`. The fake `git` exits with `1`, `0`, `2` and then `128`. The test passes when `lint:records` passes only with `1`.

### `lint:shell`

1. Run `shellcheck` on each `.sh` file that Git tracks. `.shellcheckrc` holds the settings.
2. Run `shfmt -d` on the same files. shfmt reads its style from `.editorconfig`.

The `lint-shell` pre-commit hook runs the task on a change to a shell script.

### `lint:terraform`

1. Run `terraform fmt -check -recursive -diff`.
2. For each folder that has a `.tf` file that Git tracks, run `tflint --chdir=<folder> --config=.tflint.hcl --format compact`.

`.tflint.hcl` enables the bundled `terraform` ruleset with the `all` preset, and sets `call_module_type = "local"`. The task runs TFLint in all the folders, then fails if one of them has an issue.

The `lint-terraform` pre-commit hook runs the task on a change to a `.tf` file or to `.tflint.hcl`.

## `manifests`

### `manifests:render`

The task renders the Helm charts in the `sources/` folders. It has two inputs.

First, `helm repo update`. A failure prints a warning, and the task continues.

`kubernetes/**/sources/Chart.yaml` renders to the `manifests/` folder next to `sources/`:

1. `sources/values.yaml` must exist.
2. Run `helm dependency update sources/`.
3. Run `helm template <component> sources/ -f sources/values.yaml > manifests/install.yaml`. `<component>` is the name of the folder above `sources/`. If `sources/chart.env` sets `NAMESPACE`, the task adds `--namespace <NAMESPACE>`.
4. If `install.yaml` has no `# Source:` comment, print a warning and stop for this chart.
5. Delete the `.yaml` files of `manifests/`, except `install.yaml`.
6. Split `install.yaml` at each `# Source:` comment. The file name is the template path after `templates/`, with `-` in place of `/`. A second file with the same name gets the suffix `-2`, `-3` and on.

`gitops/clusters/<cluster>/cluster.yaml` renders each of its components to `gitops/clusters/<cluster>/rendered/<component>/`:

1. Delete `gitops/clusters/<cluster>/rendered/`.
2. For each item of `infrastructure`, then of `apps`, `gitops/<group>/<component>/sources/Chart.yaml` must exist.
3. Run `helm dependency update` on the chart. A chart that two clusters use updates one time.
4. Run `helm template <component> <chart> --include-crds --namespace=<namespace>`, with these values, in this order: `gitops.cluster` set to the content of `cluster.yaml`, then `gitops/clusters/<cluster>/values/<component>.yaml` if it exists. The `values.yaml` of the chart applies first.
5. Write one file for each resource. The file names are in [GitOps layout](gitops-layout.md#rendered-files).

| Status | Condition |
| --- | --- |
| `0` | No error, or no chart at all. With no chart, the task prints a warning. |
| `1` and more | The number of charts that failed. A chart fails on a missing file or a failed `helm` command. It also fails on two resources with the same kind and name, or on a resource without a `# Source:` comment. |

The `render-manifests` pre-commit hook runs the task on a change to `kubernetes/**/sources/*.yaml`, `gitops/**/sources/**`, `gitops/**/values/**` or `gitops/clusters/<cluster>/cluster.yaml`. The hook then stages `kubernetes/` and `gitops/**/rendered/**`.

### `manifests:check`

1. Run `manifests:render`.
2. Fail if `kubernetes/**/manifests/**` or `gitops/**/rendered/**` has a change or a new file that Git does not ignore. The task prints `git status --short` and `git diff` of these paths.

| Status | Condition |
| --- | --- |
| `0` | `[INFO] ✓ All manifests are up to date.` |
| `1` | `Manifests are out of date. Run 'mise run manifests:render' and commit the changes.` |

### `manifests:validate`

The task runs `kubeconform -summary -ignore-missing-schemas` on each `.yaml` file in a `manifests/` or `rendered/` folder of `kubernetes/` and `gitops/`.

The `Validate Kubernetes Manifests` workflow runs `manifests:check`, then `manifests:validate`. It runs on a pull request that changes `gitops/`, `kubernetes/`, `.mise/tasks/manifests/`, `.mise/config.toml` or the workflow, and on a push to `main` that changes `gitops/` or `kubernetes/`.

## `schemas`

`schemas:check` validates the files of the repository. `schemas:test` tests the schemas and the checks against fixtures. The rules and the fixtures are in [Schemas](schemas.md).

The `schemas-check` and `schemas-test` pre-commit hooks and the `Validate Schemas` workflow run these tasks.

## `tf`

### `tf:docs`

For each folder in `modules/`, except `modules/_template/`, the task runs:

```bash
terraform-docs markdown table --output-file README.md --output-mode inject modules/<module>
```

terraform-docs writes the tables between the `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` lines of `README.md`.

| Status | Condition |
| --- | --- |
| `0` | All the modules, or no `modules/` folder. With no folder, the task prints a warning. |
| `1` | `terraform-docs is not installed. Install it with: brew install terraform-docs` |
| `1` and more | The number of modules that failed. |

### `tf:lock`

For each folder in `instances/` and `modules/` that has a `.tf` file, the task runs `terraform get`, then:

```bash
terraform providers lock -platform=linux_amd64 -platform=linux_arm64 -platform=darwin_amd64 -platform=darwin_arm64
```

The task skips the `.terraform/` folders and `modules/_template/`. It writes the `.terraform.lock.hcl` file of each folder. No hook or workflow runs this task.

## Related pages

- [Instance tasks](instance-tasks.md): `instance:plan`, `instance:up` and `instance:down`.
- [Policies](policies.md): the rules of `lint:policy`.
- [Schemas](schemas.md): the rules of `schemas:check` and `schemas:test`.
- [Tools](tools.md): the tools that the tasks use.
- [Install the tools](../how-to/install-the-tools.md)
- [Render manifests](../how-to/render-manifests.md)
- [Sync the GitHub labels](../how-to/sync-the-github-labels.md)
- [Change a Terraform provider version](../how-to/change-a-terraform-provider-version.md)
- [Update the Terraform module docs](../how-to/update-the-terraform-module-docs.md)
- [Rendered manifests pattern](../explanation/rendered-manifests-pattern.md)
