# Add a secret

This guide shows how to add a secret value for a consumer that has a store, or change a value that exists.

Add a secret when one of these occurs:

- a component needs a new secret, for example a new OAuth client secret;
- a value changes at its issuer, for example after a rotation.

To give a new component its first secret, refer to [Add a secret consumer](add-a-secret-consumer.md).

## Before you start

- The consumer has its store `secrets`, or its `oc-<tenant>` store.
- The scope key of the instance is on the computer.
- You have the new value from its issuer.

## Add the seed

An agent can do these steps. Skip them when only the value changes.

1. Add the seed name to the seed map of `instances/<instance>/secrets/main.tf`, under its consumer.

   For a tenant, the key is `oc-<tenant>`.

2. For a namespaced consumer, add a `data` item to the `ExternalSecret` of its component, on the store `secrets`.
3. For a namespaced consumer, set `remoteRef.key` to the seed name, and `remoteRef.property` to `value`.
4. Render the manifests:

   ```bash
   mise run manifests:render
   ```

5. Run `mise run lint`, and open a pull request.

For a tenant, only the seed map changes in this pull request.

## Write the value

Do these steps by hand. No agent writes or reads a value.

1. Stop all the agent sessions on the computer.
2. Open the SOPS file:

   ```bash
   mise run secrets:edit <instance>
   ```

3. Add or change the value under the block of its consumer. Use the seed name as the key:

   ```yaml
   <consumer>:
     <seed>: <value>
   ```

4. Save and close the editor.
5. Run `mise run lint:secrets`. SC4 and SC5 must pass.
6. Commit the SOPS file, and open a pull request. Git holds only the ciphertext.
7. Merge the pull request.
8. Do [Apply the secrets](apply-the-secrets.md#apply-the-secrets) from a clean checkout of `main` at the merged commit.

## Related pages

- [Secrets](../reference/secrets.md#sops-file-and-keys): the SOPS file, the seed map and the `ExternalSecret` fields.
- [Secrets management](../explanation/secrets-management.md#what-agents-can-and-cannot-reach): why no agent session runs during an edit.
- [Rotate a secret](rotate-a-secret.md)
- [Render manifests](render-manifests.md)
