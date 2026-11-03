# Change a Terraform provider version

This guide shows how to change the version of a Terraform provider and update the lock files.

Change a provider version by hand when Renovate did not propose the version that you need. For example, a module needs a fix of a newer provider, or a provider version has a problem. Refer to [Automated updates](../explanation/automated-updates.md).

## Before you start

- You ran `mise install`. Refer to [Install the tools](install-the-tools.md).
- You know the folders that use the provider: `instances/<instance>/` and `modules/<module>/`.

## Change the version

1. In each `required_providers` block that names the provider, set `version` to one exact version, for example `"2.38.0"`.
2. Update the lock files of all the folders:

   ```bash
   mise run tf:lock
   ```

3. Examine the changes:

   ```bash
   git diff -- '*.terraform.lock.hcl'
   ```

4. Run the checks:

   ```bash
   mise run lint
   ```

5. Commit the `.tf` files and the `.terraform.lock.hcl` files together.

The `terraform` policy refuses a version range or a provider without a `source`. Refer to [Policies](../reference/policies.md#terraform).

## Related pages

- [Mise tasks](../reference/mise-tasks.md#tflock): the `tf:lock` task and its platforms.
- [Policies](../reference/policies.md#terraform): the rules of `required_providers`.
- [Automated updates](../explanation/automated-updates.md)
