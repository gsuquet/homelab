# Change a schema

This guide shows how to change a JSON schema in `schemas/`, with the fixtures that test it.

Change a schema when one of these occurs:

- a `module.yaml`, `instance.yaml` or `cluster.yaml` needs a new field or a new value;
- a rule must refuse a value that the schema permits.

## Before you start

- You ran `mise install`. Refer to [Install the tools](install-the-tools.md).

## Change the schema

1. Open `schemas/<schema>.schema.json`.
2. Change the fields or the rules.
3. For each new permitted case, add a fixture in `schemas/tests/<schema>/valid/`.
4. For each new rule, add a fixture in `schemas/tests/<schema>/invalid/`. Give it the name of the rule that it breaks.
5. Start each new fixture with the `# yaml-language-server` line of a fixture next to it.
6. Run the tests:

   ```bash
   mise run schemas:test
   ```

7. Validate the files of the repository:

   ```bash
   mise run schemas:check
   ```

8. If a file of the repository fails, correct the file or the schema.
9. Update the tables of the schema in [Schemas](../reference/schemas.md).

## Change a check that a schema cannot do

The checks across files are in `.mise/tasks/_base/instance-checks.sh`.

1. Change `check_instance_terraform` or `check_gitops_tree`.
2. Add a case folder in `schemas/tests/instance-terraform/` or `schemas/tests/gitops-tree/`, in `valid/` or `invalid/`.
3. Name each Terraform file of a case `<name>.tf.txt`.
4. Make sure that an invalid case has exactly one error.
5. Run `mise run schemas:test`, then `mise run schemas:check`.
6. Update the `schemas:check` table in [Schemas](../reference/schemas.md#schemascheck).

## Validate a new file in the editor

1. Add the `# yaml-language-server` line at the top of the new file, with the relative path to its schema:

   ```yaml
   # yaml-language-server: $schema=../../schemas/module.schema.json
   ```

2. In VS Code, install the `redhat.vscode-yaml` extension.

For the files that have this line, refer to [Schemas](../reference/schemas.md#editor-support).

## Related pages

- [Schemas](../reference/schemas.md): the fields, the rules and the fixtures.
- [Mise tasks](../reference/mise-tasks.md#schemas): the `schemas:check` and `schemas:test` tasks.
- [GitOps layout](../reference/gitops-layout.md): the use of the `cluster.yaml` fields.
