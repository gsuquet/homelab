# Schemas

This page lists the JSON Schemas in `schemas/` and the tasks that use them.

## Files

| Schema | Validates | Location of validated files |
| --- | --- | --- |
| `schemas/module.schema.json` | Module metadata | `modules/<layer>-<component>/module.yaml` |
| `schemas/instance.schema.json` | Instance definition | `instances/<name>/instance.yaml` |

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
- A `production` instance must be `long-lived` and must not use `local` state.
- `state.backend` is `r2`, `hcp-terraform` or `local`.
- `layers.cluster` and `layers.bootstrap` are mandatory. `layers.substrate` is optional.
- The module of each layer must start with the layer name.
- Other fields are not permitted.

## Rules that the schemas cannot check

The `schemas:check` task also makes sure that `name` is equal to the folder name.

## Tasks

| Task | Action |
| --- | --- |
| `mise run schemas:test` | Validates the fixtures in `schemas/tests/`. Each file in `valid/` must pass. Each file in `invalid/` must fail. |
| `mise run schemas:check` | Validates each `module.yaml` and `instance.yaml` in the repository. |

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
