# Apply the secrets

This guide shows how to write the values of the SOPS file of an instance into its seed namespaces, with `mise run secrets:apply`.

Apply the secrets when one of these occurs:

- a pull request that changes a value in the SOPS file merged;
- a pull request that adds a consumer or a seed merged;
- after a re-create of the cluster, the `ExternalSecret` objects show `SecretSyncedError`.

Agents never do the tasks of this guide. Do them by hand.

## Before you start

- The change is merged, and the checkout is a clean copy of `main` at the merged commit:

  ```bash
  git switch main && git pull --ff-only && git status --short
  ```

- The cluster is up, for example after `mise run instance:up kind-local`.
- Argo CD synced the `external-secrets` component, so each seed namespace of the seed map exists.
- The scope key of the instance is in `keys.txt`, or in the variable that the task reads.

## Apply the secrets

1. Stop all the agent sessions on the computer.
2. Read each diff since the last apply under `instances/`, `modules/` and `.mise/`.
3. Read the diffs of the mise configuration and of each `.terraform.lock.hcl` file.
4. Run the task:

   ```bash
   mise run secrets:apply <instance>
   ```

5. If the task stops on a precondition, correct the cause and run the task again.
6. List the `ExternalSecret` objects of each consumer:

   ```bash
   kubectl -n <consumer> get externalsecret
   ```

7. Make sure that each `ExternalSecret` has the `Ready` condition.
8. Make sure that the Application of the component of each consumer stays `Synced`:

   ```bash
   kubectl -n argocd get application <component>
   ```

The task stops when the working tree is not clean, when the commit is not on `origin/main`, when the cluster is down, when a seed namespace is missing, or when the kubeconfig is not clean. For the preconditions, refer to [Secrets](../reference/secrets.md#secretsplan-secretsapply-and-secretsdestroy).

## Copy a new value at once

ESO copies a new seed value at its next refresh. To copy it at once, set a new value on the `force-sync` annotation:

```bash
kubectl -n <consumer> annotate externalsecret <name> force-sync=$(date +%s) --overwrite
```

## Apply the secrets after a re-create of the cluster

A re-created cluster has no seeds. Each consumer Secret keeps its last value, and its `ExternalSecret` shows `SecretSyncedError`.

1. Wait for the message of the agent that re-created the cluster, or look at the `Ready` condition of each `ExternalSecret`.
2. Do [Apply the secrets](#apply-the-secrets). Terraform makes each seed again.
3. Let an agent run `mise run vertex:jwks` and open the pull request with the new public keys.
4. Review and merge that pull request, then apply `accounts/gcp/`.

## Check that the state holds no value

Do this check with a dummy value in the SOPS file, before the first real value, and after each change to the version of `carlpett/sops` or `hashicorp/kubernetes`.

1. Merge a dummy value in the SOPS file, then apply it:

   ```bash
   mise run secrets:apply <instance>
   ```

2. Make a saved plan, and save the output of the task:

   ```bash
   mise run secrets:plan <instance> > <output-file>
   ```

3. Run `mise run secrets:apply <instance>` again, to refresh the state.
4. Search the state, its backup, the saved plan and each output for the dummy value and for its base64 form.

The check passes when no search finds the value. If a search finds it, do [Create the seeds by hand](#create-the-seeds-by-hand).

## Create the seeds by hand

Do this only when the state check fails. Real values then never go into Terraform.

1. Delete the state and the plan file of the secrets root module.
2. For each seed, write the value from the SOPS file into its seed namespace:

   ```bash
   sops decrypt --extract '["<consumer>"]["<seed>"]' <file> \
     | kubectl -n secret-seeds-<consumer> create secret generic <seed> --from-file=value=/dev/stdin
   ```

3. Keep this method until a fix or a remote state backend exists.

## Remove the secrets of an instance

1. Remove the `ExternalSecret` objects from their components in a pull request, and merge it. Kubernetes deletes each consumer Secret through its owner reference.
   Do not delete an `ExternalSecret` by hand: Argo CD self-heal makes it again.
2. Stop all the agent sessions.
3. Update the checkout to the merged commit of `main`.
4. Destroy the secrets root module. This deletes the seeds:

   ```bash
   mise run secrets:destroy <instance>
   ```

5. Keep the SOPS file, or remove it in a pull request.

## Related pages

- [Secrets](../reference/secrets.md#secrets-root-module): the secrets root module, the tasks and the preconditions.
- [Secrets management](../explanation/secrets-management.md#why-terraform-decrypts-in-a-separate-root-module): why only a person applies the secrets.
- [Add a secret](add-a-secret.md)
- [Rotate a secret](rotate-a-secret.md)
- [Add a secret consumer](add-a-secret-consumer.md)
