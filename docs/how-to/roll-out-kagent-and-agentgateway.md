# Roll out kagent and agentgateway

This guide rolls out milestone M1: kagent and agentgateway on `kind-local`, with Gemini on Vertex AI through Workload Identity Federation. The reasons are in [kagent and agentgateway (explanation)](../explanation/kagent-and-agentgateway.md). The objects, the checks and the done criteria are in [kagent and agentgateway (reference)](../reference/kagent-and-agentgateway.md).

Each step R2 to R5 is one PR. R1 has three PRs: the JWKS tooling, `accounts/gcp/`, and the file of the second laptop. The checks are the numbered done criteria of the reference page. To undo the rollout, refer to [Roll back kagent and agentgateway](roll-back-kagent-and-agentgateway.md).

## R1. Prerequisites and the Google Cloud side

Wait for these items first:

- The kind node image v1.37.
- SC16 of the [secrets design](../reference/secrets.md). M1 needs no ESO consumer.

Then, in this order:

1. On the first laptop, run `mise run instance:up kind-local`.
2. Open a PR with the task `vertex:jwks` and its `--check` option.
3. In the same PR, add the lint script for `accounts/gcp/jwks/`, with its allowlist of laptops and of JWK members.
4. In the same PR, write the issuer and the first key file:

   ```sh
   mise run vertex:jwks kind-local <laptop> --init
   mise run vertex:jwks kind-local <laptop>
   ```

   `--init` writes `accounts/gcp/jwks/issuer.txt`, only when it does not exist. If the base branch has no `accounts/gcp/jwks/issuer.txt`, the PR may add exactly `issuer.txt` and one `<laptop>.json`. Otherwise it changes exactly one file.
5. On that laptop, run `mise run vertex:jwks kind-local <laptop> --check`. Then merge.
6. Open a PR for `accounts/gcp/`. Put the Vertex project and its budget first (G2 in [Provider accounts](../reference/provider-accounts.md#free-tier-guardrails)).
7. In the same PR, add the Vertex AI API, the pool, the provider with the key set from Git, and the service account.
8. In the same PR, add the custom role, the binding, and the kill switch if [the spend kill switch decision](../reference/kagent-and-agentgateway.md#a-spend-kill-switch-for-the-vertex-project) selects one.
9. Merge. Apply `accounts/gcp/` in one apply session, outside of agent sessions.
10. On the second laptop, add its file through a PR. Follow [Generate the Vertex JWKS](generate-vertex-jwks.md).
11. On the second laptop, run `--check`, merge, and apply again.

Checks: the budget and kill-switch part of done criterion 18.

## R2. agentgateway

1. Add the component `agentgateway` in `agentgateway-system`.
2. Add the `Gateway`, the backend `gemini`, the route and the `ConfigMap` of the credential configuration.
3. Add the `AgentgatewayParameters` with the token volume, `GOOGLE_APPLICATION_CREDENTIALS` and the `ClusterIP` Service type.
4. Add the `NetworkPolicy` and set `rbac.gatewayNamespaces: [agentgateway-system]`.
5. Add the `AgentgatewayPolicy` with the rate limit on the route. Done criterion 18 tests it.
6. After `instance:up`, make sure that the key set in Git has the keys of the cluster (R1).

**Stop rule.** If open check (a) or (b) fails, stop. Decide [the fallback if the federation fails](../reference/kagent-and-agentgateway.md#the-fallback-if-the-federation-fails) first.

Checks: done criteria 2, 3, 9, 14 and 17, the agentgateway part of 8, and the rate-limit part of 18.

## R3. kagent

Wait for these items first:

- The SC7 exception for `kagent-postgresql` in the [secrets design](../reference/secrets.md) (option A of [The kagent database](../explanation/kagent-and-agentgateway.md#the-kagent-database)).
- [A key for the kagent `ModelConfig`](../reference/kagent-and-agentgateway.md#a-key-for-the-kagent-modelconfig), if the agent runtime needs a key.

Then:

1. Add the component `kagent` in `kagent`, with the values of the reference page.
2. Add the `ModelConfig` `default-model-config` and the agent `cluster-reader`.
3. Add the `NetworkPolicy` and the Conftest check for `Agent` objects.
4. Put the AppProject requirements into step R5 of [Roll out OpenChoreo](roll-out-openchoreo.md).

**Stop rule.** If the agent runtime needs a key, stop. Decide [the key for the `ModelConfig`](../reference/kagent-and-agentgateway.md#a-key-for-the-kagent-modelconfig) first.

Checks: done criteria 1, 4 to 8, 10 to 13, 15 and 16.

## R4. Documentation

1. Add a how-to page "Ask an agent on kind-local".
2. Add a reference page for the agent tools and their rights.

## R5. Milestone

1. Write the checks of the done criteria into the M1 milestone description. Use the mapping on the reference page.

## Stop rules

- **Before each check.** Start from an empty state: `mise run instance:up`, then [Generate the Vertex JWKS](generate-vertex-jwks.md). The checks start after the apply.
- **A JWKS PR.** Do not merge it until `--check` passes on the laptop of the file.
- **The federation.** If open check (a) or (b) fails, stop at R2 and decide [the fallback](../reference/kagent-and-agentgateway.md#the-fallback-if-the-federation-fails).
- **The agent key.** If the agent runtime needs a key, stop at R3 and decide [the key for the `ModelConfig`](../reference/kagent-and-agentgateway.md#a-key-for-the-kagent-modelconfig).
- **agentgateway fails, kagent works.** No direct path exists. M1 waits for the fix of agentgateway.
