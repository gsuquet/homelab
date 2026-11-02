# Update the Terraform module docs

This guide shows how to update the input and output tables of the Terraform modules, in `modules/<module>/README.md` and in `docs/reference/terraform-modules/`.

Update the docs after a change to a variable, an output, a provider or a requirement of a module.

## Before you start

- You ran `mise install`. Refer to [Install the tools](install-the-tools.md).

## Update the docs

1. Generate the docs:

   ```bash
   mise run doc:generate
   ```

2. Examine the changes:

   ```bash
   git diff -- modules docs/reference/terraform-modules
   ```

3. Commit the module and its docs together.

The `generate-docs` pre-commit hook does step 1 on a commit that changes a file in `modules/`, and stages the result.

## Check that the docs are current

```bash
mise run doc:check
```

The task generates the docs again, and fails when a file changes.

## Related pages

- [Mise tasks](../reference/mise-tasks.md#doc): the `doc:generate`, `doc:check` and `tf:docs` tasks.
- [Terraform modules](../reference/terraform-modules/index.md)
