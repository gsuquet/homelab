# Test a branch on Kind

This guide shows how to make `kind-local` sync a branch, so that you can test a GitOps change before the merge. By default, each Application syncs `main`.

## Prerequisites

- You ran `mise install`.
- Your change is on a branch, and the branch has a draft pull request.

## Point `kind-local` to the branch

1. Add the file `gitops/clusters/kind-local/values/argocd.yaml`:

   ```yaml
   gitops:
     targetRevision: <branch>
   ```

2. Render the manifests:

   ```bash
   mise run manifests:render
   ```

3. Check that `gitops/clusters/kind-local/rendered/argocd/application-*.yaml` have `targetRevision: <branch>`.
4. Commit the change and push the branch. Argo CD reads the branch from GitHub, so the branch must contain the rendered files.

   The Conftest policy refuses an Application that does not sync `main`. Thus `mise run lint` and the `lint-policy` pre-commit hook fail while the file exists. This failure stops a merge of the test value.

5. Create the cluster again. Terraform applies the bootstrap manifests only at creation:

   ```bash
   mise run instance:down kind-local
   mise run instance:up kind-local
   ```

   `instance:up` reads the rendered folder of your working copy, so run it on the branch.

6. Check that the Applications sync the branch:

   ```bash
   kubectl -n argocd get applications \
     -o custom-columns=NAME:.metadata.name,REVISION:.spec.source.targetRevision,SYNC:.status.sync.status
   ```

Each new push to the branch reaches `kind-local` within about 3 minutes. To apply it at once, refer to [Force a sync](force-a-sync.md).

## Remove the test value before the merge

1. Delete `gitops/clusters/kind-local/values/argocd.yaml`.
2. Run `mise run manifests:render`.
3. Run `mise run lint`. It passes again.
4. Commit and push the branch.

Argo CD reads the branch one more time and applies `targetRevision: main`. `kind-local` then syncs `main` again.

## Related pages

- [GitOps layout](../reference/gitops-layout.md#values): the values order and `gitops.targetRevision`.
- [Mise tasks](../reference/mise-tasks.md): the `instance:up` and `instance:down` tasks.
- [Upgrade Argo CD](upgrade-argo-cd.md)
