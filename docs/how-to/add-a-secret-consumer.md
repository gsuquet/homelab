# Add a secret consumer

This guide shows how to give a component, or an OpenChoreo tenant, its secrets through a seed namespace and ESO.

Add a secret consumer when a component or a tenant needs its first secret. To add a secret to a consumer that exists, refer to [Add a secret](add-a-secret.md).

An agent can write all the code of this guide. No agent writes or reads a value.

## Before you start

- The cluster runs the `external-secrets` component.
- You know the namespace of the consumer, for example `thunder`, and the names of its seeds.
- The consumer is not `kagent`. The consumer is not `agentgateway-system`.

## Add a namespaced consumer

Do all these changes in one pull request, together with the component of the consumer. SC9 refuses a consumer without its component, and a component store without its consumer.

1. Add the consumer to the consumer list in the values of `gitops/infrastructure/external-secrets/`.
2. In the component of the consumer, add these objects from the shared store template:
   - the ServiceAccount `eso-seed-reader`;
   - the `SecretStore` `secrets`, with `remoteNamespace: secret-seeds-<consumer>` and `server.caProvider`;
   - the token `Role` and `RoleBinding` `eso-token-eso-seed-reader`.
3. Add an `ExternalSecret` on the store `secrets`.
4. Set `property: value` in each `remoteRef`. Do not use `dataFrom.find`.
5. Add each seed name to the seed map of `instances/<instance>/secrets/main.tf`, under the consumer.
6. Render the manifests:

   ```bash
   mise run manifests:render
   ```

7. Run `mise run lint`. SC7, SC9, SC15 and SC16 must pass.
8. Open the pull request.

For the fields of each object, refer to [Namespaced stores](../reference/secrets.md#namespaced-stores).

## Add an OpenChoreo tenant

1. Make sure that the tenant name is a DNS label with no `-`.
2. If this is the second tenant, make sure that the OpenChoreo cluster agent uses the repository role.
3. Add the tenant to the tenant list in the values of `gitops/infrastructure/external-secrets/`.
4. Render the manifests with `mise run manifests:render`.
5. Make sure that the store `oc-<tenant>` has one condition: `namespaceRegexes: ["^dp-<tenant>-"]`.
6. Add each seed name to the seed map of `instances/<instance>/secrets/main.tf`, under the tenant.
7. Run `mise run lint`. SC9 must pass.
8. Open the pull request.

The component renders the seed namespace `secret-seeds-oc-<tenant>`, its ServiceAccount, its RBAC and the store `oc-<tenant>`. For the fields, refer to [OpenChoreo tenant stores](../reference/secrets.md#openchoreo-tenant-stores).

## Add the values

Do these steps by hand, after the merge.

1. Make sure that Argo CD synced the seed namespace, `secret-seeds-<consumer>` or `secret-seeds-oc-<tenant>`:

   ```bash
   kubectl get namespace <seed-namespace>
   ```

2. Do [Write the value](add-a-secret.md#write-the-value) for each seed.
3. Do [Apply the secrets](apply-the-secrets.md#apply-the-secrets).
4. Make sure that the store is valid and that each `ExternalSecret` is in sync:

   ```bash
   kubectl -n <consumer> get secretstore secrets
   kubectl -n <consumer> get externalsecret
   ```

   For a tenant, check the store with `kubectl get clustersecretstore oc-<tenant>`.

## Related pages

- [Secrets](../reference/secrets.md#consumers): the consumers, the store fields and the SC9 rules.
- [Secrets management](../explanation/secrets-management.md#why-seed-namespaces-and-one-store-per-consumer): why each consumer has its own seed namespace and store.
- [Add a GitOps component](add-a-gitops-component.md)
- [Add a secret](add-a-secret.md)
- [Apply the secrets](apply-the-secrets.md)
