# Import provider resources

This guide brings existing resources of a provider account under Terraform, in `accounts/<account>/`. The rules are in [Provider accounts](../reference/provider-accounts.md).

Agents write the code and the import blocks. Only you run `plan` and `apply`, outside of agent sessions.

## Steps

1. **Inventory.** List the resources of the account in the dashboard or the API. For Cloudflare, `cf-terraforming generate` writes Terraform code for the resources of one type in a zone or an account ([Cloudflare: import resources](https://developers.cloudflare.com/terraform/advanced-topics/import-cloudflare-resources/)). The Cloudflare inventory also checks that the "apps" of the dashboard are only Zero Trust Access applications (`cloudflare_zero_trust_access_application`). If you find another type, stop and ask.
2. **Code.** Write an `import` block and a `resource` block for each resource ([HashiCorp: import block](https://developer.hashicorp.com/terraform/language/block/import)). `terraform plan -generate-config-out=<file>` can write the `resource` blocks from the `import` blocks ([HashiCorp: import](https://developer.hashicorp.com/terraform/language/import)).
3. **Secret review.** Read all the generated code before the commit. Refer to "Rules for generated code".
4. **Plan.** The plan must show only imports. Each change or destroy in the plan is a difference between the code and the account. Correct the code until the plan has no change.
5. **Apply.** Apply the plan yourself. Then the state holds the resources.
6. **Drift check.** Run the drift check of [Provider accounts](../reference/provider-accounts.md#drift-detection).

Use the `import` blocks as the primary method. `cf-terraforming` is a help for the inventory. The order of the import depends on the state: while an account uses local state, import only the resources that hold no secret.

## Rules for generated code

The repository is public.

- Configuration generation is experimental, and its format can change ([HashiCorp: generating configuration](https://developer.hashicorp.com/terraform/language/import/generating-configuration)). Review the output before it goes into Git. The page does not tell how the output handles sensitive values. The same applies to the output of `cf-terraforming`.
- Remove each secret from the generated code before the commit. The secret scan of pre-commit (`Detect hardcoded secrets`) is a second control, not the first.
- Never set `tunnel_secret` in the code. The provider marks it sensitive. A new secret can disconnect `olympus` from its tunnel. A plan that updates or replaces the tunnel of `olympus` blocks the import.
- Record the manual items in `accounts/<account>/README.md`, for example the registration of `gsuquet.com`.

## Move a resource to another root module

For example, the `olympus` tunnel and its DNS records move from `accounts/cloudflare/` to `instances/olympus/` after the migration.

1. Import the resources into the new root module, with `import` blocks.
2. In the old root module, add a `removed` block with `lifecycle { destroy = false }` for each resource.
3. Check that both plans show no destroy. A `removed` block without `destroy = false` deletes the tunnel.

## Take a resource out of Terraform

Use `terraform state rm`, or a `removed` block with `lifecycle { destroy = false }`. A `removed` block without it destroys the resource ([HashiCorp: removed block](https://developer.hashicorp.com/terraform/language/block/removed)).
