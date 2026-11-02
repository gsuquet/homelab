# Add or change a policy rule

This guide shows how to add a Conftest rule to a policy in `policy/`, or change a rule.

Add or change a rule when one of these occurs:

- a review finds a file problem that a check can find each time;
- a rule refuses a file that the repository permits, or permits a file that it refuses.

For a label or annotation check, change `policy/data/labels.yaml` first. Refer to [Label a GitOps component](label-a-gitops-component.md).

## Before you start

- You ran `mise install`. Refer to [Install the tools](install-the-tools.md).
- You know the namespace of the rule. Refer to [Policies](../reference/policies.md).

## Change the rule

1. Open `policy/<namespace>/<namespace>.rego`.
2. Add or change the rule. Use `deny` for an error, or `warn` for a warning.
3. Start the message with the path of the file, as the other rules do.
4. Open `policy/<namespace>/<namespace>_test.rego`.
5. Add a test for each case that the rule permits.
6. Add a test for each case that the rule refuses.
7. Run the tests:

   ```bash
   conftest verify --policy policy --data policy/data
   ```

8. Run the checks on the repository:

   ```bash
   mise run lint:policy
   ```

9. If the check refuses a file of the repository, correct the file or the rule.
10. Update the table of the rule in [Policies](../reference/policies.md), or in [Labels and annotations](../reference/labels-and-annotations.md#checks) for a K check.

## Add a policy namespace

1. Create `policy/<namespace>/<namespace>.rego` with `package <namespace>`.
2. Create `policy/<namespace>/<namespace>_test.rego` with `package <namespace>_test`.
3. In `.mise/tasks/lint/policy.sh`, add a `conftest_files <namespace> ... -- <pathspec>` line.
4. In `.pre-commit-config.yaml`, add the input files to the `files` pattern of the `lint-policy` hook.
5. Run `mise run lint:policy`.
6. Add a section for the namespace to [Policies](../reference/policies.md).

## Related pages

- [Policies](../reference/policies.md): the rules, their levels and the inputs.
- [Labels and annotations](../reference/labels-and-annotations.md): the K checks.
- [Mise tasks](../reference/mise-tasks.md#lintpolicy): the `lint:policy` task.
