# Add a secret consumer

This page tells you how to give a component its secrets through a seed namespace and ESO. The rules are in [Secrets (reference)](../reference/secrets.md). The reasons are in [Secrets management (explanation)](../explanation/secrets-management.md).

An agent can write all the code of this procedure. An agent never writes or reads a value.

## Before you start

- The `external-secrets` component is on the cluster.
- You know the namespace of the consumer, for example `thunder`, and the names of its seeds.

## Add a namespaced consumer

Do all these changes in one PR, together with the component of the consumer. SC9 checks both directions.

1. Add the consumer to the consumer list in the values of `gitops/infrastructure/external-secrets/`.
2. In the component of the consumer, add the ServiceAccount `eso-seed-reader`, from the shared template.
3. In the same component, add the `SecretStore` `secrets`, from the shared template.
4. Set `remoteNamespace` of the store to `secret-seeds-<consumer>`.
5. Add an `ExternalSecret` that refers to the store `secrets`.
6. In each `remoteRef`, set `property: value`. Do not use `dataFrom.find`.
7. Add each seed key to the seed map of `instances/<instance>/secrets/main.tf`, under its consumer.
8. Render the manifests with `mise run manifests:render`.
9. Run `mise run lint`. SC7, SC9, SC15 and SC16 must pass.
10. Open the PR.

## Add the values

Do these steps by hand, outside of agent sessions, after the merge.

1. Make sure that Argo CD synced the seed namespace `secret-seeds-<consumer>`.
2. Do [Change a secret value](apply-secrets.md#change-a-secret-value) for each seed.
3. Do [Apply the secrets](apply-secrets.md#apply-the-secrets).
4. Run `kubectl -n <consumer> get externalsecret`, and make sure each one is in sync.

## Add an OpenChoreo tenant

OpenChoreo cells use a `ClusterSecretStore`, not a namespaced store.

1. Make sure the tenant name is a DNS label without `-`.
2. Before a second tenant, make sure question 13 B of the [OpenChoreo platform](../explanation/openchoreo-platform.md) is done.
3. Add the tenant to the tenant list of the `external-secrets` component.
4. The component renders `secret-seeds-oc-<tenant>`, its ServiceAccount, its RBAC and the store `oc-<tenant>`.
5. Make sure the store has exactly one condition: `namespaceRegexes: ["^dp-<tenant>-"]`.
6. Run `mise run lint`. SC9 must pass.
7. After the merge, add the values and apply them, as for a namespaced consumer.

## Do not

- Do not put a `kind: Secret` with data into `gitops/`. SC7 refuses it.
- Do not use `data "sops_file"`. SC10 refuses it.
- Do not run a `terraform` command in `instances/<instance>/secrets/`, if you are an agent.
- Do not add a store to `kagent`. Do not add one to `agentgateway-system`, except with the fallback of question 14 of [kagent and agentgateway](../explanation/kagent-and-agentgateway.md). Refer to [Secrets (reference)](../reference/secrets.md#consumers).
