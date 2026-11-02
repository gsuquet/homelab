# Schemas

The JSON schemas are in `schemas/`. They use JSON Schema draft 2020-12. `mise run schemas:check` validates the files of the repository against them, and `mise run schemas:test` tests them against fixtures in `schemas/tests/`. Both tasks use `check-jsonschema`.

| Schema | `kind` | Validated files |
| --- | --- | --- |
| `schemas/module.schema.json` | `Module` | `modules/<module>/module.yaml` |
| `schemas/instance.schema.json` | `Instance` | `instances/<instance>/instance.yaml` |
| `schemas/gitops-cluster.schema.json` | `GitOpsCluster` | `gitops/clusters/<cluster>/cluster.yaml` |

Each validated file has `apiVersion: infra.gsuquet.com/v1alpha1`. No schema permits a field that it does not list.

## Module schema

| Field | Required | Value |
| --- | --- | --- |
| `name` | Yes | The layer, a hyphen, then lowercase letters, digits and hyphens. A maximum of 63 characters. For example `cluster-kind`. |
| `layer` | Yes | `substrate`, `cluster` or `bootstrap`. The `name` starts with the layer. |
| `tool` | Yes | `terraform` or `pulumi`. |
| `description` | Yes | 10 to 200 characters. |
| `maturity` | Yes | `experimental`, `stable` or `deprecated`. |
| `contract.requires` | No | A list of `snake_case` keys, each one time only. |
| `contract.provides` | No | A list of `snake_case` keys, each one time only. |

## Instance schema

| Field | Required | Value |
| --- | --- | --- |
| `name` | Yes | Lowercase letters, digits and hyphens. A maximum of 40 characters. |
| `description` | Yes | 10 to 200 characters. |
| `purpose` | Yes | `production`, `test` or `demo`. |
| `lifecycle.type` | Yes | `long-lived` or `ephemeral`. |
| `lifecycle.ttl` | For `ephemeral` only | A number of hours or days, for example `8h` or `2d`. A `long-lived` instance has no `ttl`. |
| `state.backend` | Yes | `r2`, `hcp-terraform` or `local`. |
| `layers.substrate.modules` | No | A list of modules that start with `substrate-`. |
| `layers.cluster.modules` | Yes | A list of modules that start with `cluster-`. |
| `layers.bootstrap.modules` | Yes | A list of modules that start with `bootstrap-`. |

Each `modules` list has one or more names, in the order of installation, and no name two times.

| `purpose` | Permitted `lifecycle.type` | Permitted `state.backend` |
| --- | --- | --- |
| `production` | `long-lived` | `r2`, `hcp-terraform` |
| `demo` | `long-lived`, `ephemeral` | `r2`, `hcp-terraform` |
| `test` | `long-lived`, `ephemeral` | `r2`, `hcp-terraform`, `local` |

## GitOps cluster schema

| Field | Required | Value |
| --- | --- | --- |
| `name` | Yes | Lowercase letters, digits and hyphens. A maximum of 40 characters. |
| `infrastructure` | Yes | A list of components in `gitops/infrastructure/`. The list can be empty. |
| `apps` | Yes | A list of components in `gitops/apps/`. The list can be empty. |

Each component of a list has these fields. A list has no item two times.

| Field | Required | Value |
| --- | --- | --- |
| `name` | Yes | The folder name of the component, and the name of its Argo CD Application. Lowercase letters, digits and hyphens. A maximum of 53 characters. |
| `namespace` | Yes | The destination namespace. Lowercase letters, digits and hyphens. A maximum of 63 characters. |
| `dependsOn` | No | A list of component names, each one time only. |

The use of each field is in [GitOps layout](gitops-layout.md#clusteryaml).

## `schemas:check`

The task checks these rules. The functions of the `gitops/` and Terraform checks are in `.mise/tasks/_base/instance-checks.sh`.

| Input | Rule |
| --- | --- |
| Each folder in `modules/` and `instances/` | The folder has a `module.yaml` or an `instance.yaml` that complies with its schema. Its `name` is equal to the folder name, except in `modules/_template/`. |
| Each module in the `layers` of an `instance.yaml` | The folder `modules/<module>/` exists, and its `module.yaml` has the same `layer`. |
| The `.tf` files of an instance | Each `module` block with `source = "../../modules/<module>"` uses a module of the `layers`, and each module of the `layers` has such a block. Comment lines do not count. |
| The `.tf` files of an instance that uses `cluster-kind` | The files have an `output "cluster_name"` block. `instance:up` reads it. |
| The `.tf` files of an instance | The files have a `backend` or `cloud` block when `state.backend` is not `local`, and none when it is `local`. |
| Each folder in `gitops/clusters/` | The folder has a `cluster.yaml` that complies with its schema. Its `name` is equal to the folder name. |
| Each `cluster.yaml` | `infrastructure` lists `argocd`. Argo CD manages itself through this item. |
| Each `cluster.yaml` | No two components have the same `name`, also across `infrastructure` and `apps`. |
| Each `dependsOn` | The name is a component of the same cluster. |
| Each component of a `cluster.yaml` | `gitops/<group>/<component>/sources/Chart.yaml` exists, and `gitops/clusters/<cluster>/rendered/<component>/` has a `Namespace` with the name of the `namespace` field. |
| Each file in `gitops/clusters/<cluster>/values/` | The file name is `<component>.yaml`, for a component of the cluster. `manifests:render` ignores the other files. |
| Each folder in `gitops/infrastructure/` and `gitops/apps/` | The folder has `sources/Chart.yaml` and `sources/templates/namespace.yaml`. |
| Each dependency in a `sources/Chart.yaml` | The `repository` starts with `https://` or `oci://`. |
| `gitops/*/*/sources/charts/` | Git tracks no file in it. `helm dependency update` writes the chart archives there. |
| Each `.tf` file of `instances/<instance>/` that names `gitops/clusters/<cluster>/rendered/argocd` | `<cluster>` is equal to `<instance>`. |

The task prints each error, then fails with `<n> file(s) do not comply with their schema.` It exits with `0` after `✓ All module.yaml, instance.yaml and GitOps cluster files comply with their schema.`

## `schemas:test`

The fixtures are in `schemas/tests/`. Each `.tf` fixture has the extension `.tf.txt`, so that the Terraform linters do not read it. The task copies each case folder to a temporary folder and renames each `.tf.txt` file to `.tf` before the check.

| Folder | Check | Pass condition |
| --- | --- | --- |
| `<schema>/valid/*.yaml` | `check-jsonschema` with `schemas/<schema>.schema.json` | The file passes. |
| `<schema>/invalid/*.yaml` | The same | The file fails. |
| `instance-terraform/valid/<case>/` | The Terraform checks of an instance, on `instance.yaml` and `main.tf.txt` | No error. |
| `instance-terraform/invalid/<case>/` | The same | Exactly one error. |
| `gitops-tree/valid/<case>/` | The `gitops/` checks, with `<case>/` as the root of the repository | No error. |
| `gitops-tree/invalid/<case>/` | The same | Exactly one error. |

`<schema>` is the file name of a schema without `.schema.json`, for example `module`. Each schema must have a `valid/` and an `invalid/` folder, else the task fails. The name of an invalid fixture tells the rule that it breaks, for example `production-local-state.yaml`.

## Hooks and workflows

| Runner | Tasks | Trigger |
| --- | --- | --- |
| `schemas-test` pre-commit hook | `schemas:test` | A change in `schemas/`, in `.mise/tasks/schemas/`, or to `.mise/tasks/_base/instance-checks.sh`. |
| `schemas-check` pre-commit hook | `schemas:check` | A change to a schema, a `module.yaml`, an `instance.yaml`, a `.tf` file of an instance, a file in `gitops/`, or `.mise/tasks/_base/instance-checks.sh`. |
| `Validate Schemas` workflow | `schemas:test`, then `schemas:check` | A pull request or a push to `main` that changes these files. A pull request that changes `.mise/config.toml` or the workflow also runs it. |
| `Lint` workflow | Both, through `mise run lint` | Each pull request and each push to `main`. |

## Editor support

The first line of each validated file and of each schema fixture names its schema for `yaml-language-server`, with a relative path:

```yaml
# yaml-language-server: $schema=../../schemas/module.schema.json
```

`.vscode/extensions.json` recommends the `redhat.vscode-yaml` extension, which uses `yaml-language-server`.

## Related pages

- [GitOps layout](gitops-layout.md): the use of each field of `cluster.yaml`.
- [Instance tasks](instance-tasks.md): the tasks that read `instance.yaml`.
- [Mise tasks](mise-tasks.md): all the tasks.
- [Change a schema](../how-to/change-a-schema.md)
- [Add a GitOps component](../how-to/add-gitops-component.md)
