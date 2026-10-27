# Module template

> **Draft.** The module standards are not decided yet. This template shows the minimum that passes all the checks. Do not use it as a standard until the owner approves the standards.

## Use the template

1. Copy this folder to `modules/<layer>-<component>/`, for example `modules/bootstrap-cilium/`.
2. In `module.yaml`, change `name`, `layer` and `description`. The `name` must be equal to the folder name.
3. Replace the example resource, variable and output.
4. Run `mise run lint`.

## Files

| File | Content |
| --- | --- |
| `module.yaml` | Module metadata. `schemas/module.schema.json` validates it. |
| `terraform.tf` | The `terraform` block: Terraform version and required providers. |
| `main.tf` | The primary resources. |
| `variables.tf` | Input variables, each with a `description` and a `type`. |
| `outputs.tf` | Outputs, each with a `description`. |
| `AGENTS.md` | Instructions for agents that change the module. |

## Open questions for the module standards

- File names: `terraform.tf` or `versions.tf`. One `main.tf`, or one file for each resource group.
- The constraint for `required_version`.
- Rules for variable names, validation and default values.
- How the `contract` keys in `module.yaml` map to variables and outputs, and which check enforces this.
- Tests: `terraform test`, an example root module, or both.
- A standard pattern for modules that install a Helm chart (values template, namespace, CRDs).
- The minimum content of `AGENTS.md`.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
