# Schemas

This page lists the JSON Schemas in `schemas/` and the tasks that use them.

## Files

| Schema | Validates | Location of validated files |
| --- | --- | --- |
| `schemas/module.schema.json` | Module metadata | `modules/<layer>-<component>/module.yaml` |
| `schemas/instance.schema.json` | Instance definition | `instances/<name>/instance.yaml` |
| `schemas/gitops-cluster.schema.json` | GitOps entry point of a cluster | `gitops/clusters/<name>/cluster.yaml` |

## Rules in the module schema

- `name` starts with the layer: `substrate-`, `cluster-` or `bootstrap-`.
- `name` uses lowercase letters, digits and hyphens. Maximum 63 characters.
- `layer` is `substrate`, `cluster` or `bootstrap`. It must agree with the `name` prefix.
- `tool` is `terraform` or `pulumi`.
- `maturity` is `experimental`, `stable` or `deprecated`.
- `contract.requires` and `contract.provides` contain `snake_case` keys.
- Other fields are not permitted.

## Rules in the instance schema

- `purpose` is `production`, `test` or `demo`.
- `lifecycle.type` is `long-lived` or `ephemeral`.
- An `ephemeral` instance must have a `ttl`, in hours (`8h`) or days (`2d`). A `long-lived` instance must not have a `ttl`.
- A `production` instance must be `long-lived`.
- Only a `test` instance can use `local` state. A `production` or `demo` instance must use remote state, because more than one machine or a CI job can run it.
- `state.backend` is `r2`, `hcp-terraform` or `local`.
- `layers.cluster` and `layers.bootstrap` are mandatory. `layers.substrate` is optional.
- Each layer has a `modules` list, in the order of installation. The list has one or more modules, and no module two times.
- The name of each module must start with the layer name.
- Other fields are not permitted.

## Rules in the GitOps cluster schema

- `name`, `infrastructure` and `apps` are mandatory. A list can be empty.
- Each item has a `name` and a `namespace`. Both use lowercase letters, digits and hyphens.
- `dependsOn` is optional. It is a list of component names.
- A list has no item two times.
- Other fields are not permitted.

## Rules that the schemas cannot check

The `schemas:check` task also checks these rules:

- `name` is equal to the folder name. `modules/_template/` is not checked for this rule.
- Each module in the `layers` of an `instance.yaml` has a folder in `modules/`, and its `module.yaml` has the same `layer`.
- The Terraform files of an instance use each module of its `layers` with `source = "../../modules/<module>"`, and they use no other module.
- If an instance uses `cluster-kind`, its Terraform files have an `output "cluster_name"` block. `instance:up` reads it.
- The Terraform files of an instance have a `backend` block if `state.backend` is not `local`. They have no `backend` block if `state.backend` is `local`.
- Each folder in `gitops/clusters/` has a `cluster.yaml`, and its `name` is equal to the folder name.
- Each `cluster.yaml` lists `argocd` in `infrastructure`. Argo CD manages itself through this item.
- Two components of one cluster do not have the same name, because the name is also the name of the Argo CD Application.
- Each name in `dependsOn` is a component of the same cluster.
- Each component in `cluster.yaml` has `gitops/<group>/<component>/sources/Chart.yaml`, and `gitops/clusters/<name>/rendered/<component>/` contains a `Namespace` with the name of the `namespace` field.
- Each file in `gitops/clusters/<name>/values/` has the name of a component of the cluster. Else `manifests:render` ignores the file.
- Each folder in `gitops/infrastructure/` and `gitops/apps/` has `sources/Chart.yaml` and `sources/templates/namespace.yaml`. All components use the rendered manifests pattern and ship their own `Namespace`.
- An instance that bootstraps Argo CD from `gitops/clusters/<cluster>/rendered/argocd` has the name of the cluster.

## Tasks

| Task | Action |
| --- | --- |
| `mise run schemas:test` | Validates the fixtures in `schemas/tests/`. Each file in `valid/` must pass. Each file in `invalid/` must fail. The `gitops-tree/` cases test the `gitops/` checks: each folder is a small repository root. |
| `mise run schemas:check` | Validates each `module.yaml`, `instance.yaml` and the `gitops/` tree in the repository. |

The pre-commit hooks and the `Validate Schemas` workflow run the same tasks.

## Change a schema

1. Change the schema file.
2. Add a fixture in `valid/` for each new permitted case.
3. Add a fixture in `invalid/` for each new rule. Use the file name to tell which rule it breaks.
4. Run `mise run schemas:test`.

## Editor support

Add this line at the top of a YAML file to get validation and completion in editors that use `yaml-language-server`:

```yaml
# yaml-language-server: $schema=<relative path>/schemas/module.schema.json
```
