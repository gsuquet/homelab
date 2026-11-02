# Generate the Vertex JWKS

This guide updates the public key set of `kind-local` in `accounts/gcp/jwks/` after a re-create of the cluster. Google uses that key set to accept the proxy token of agentgateway. The reasons are in [kagent and agentgateway (explanation)](../explanation/kagent-and-agentgateway.md#the-vertex-ai-federation). The files and the checks are in [kagent and agentgateway (reference)](../reference/kagent-and-agentgateway.md#jwks-files-and-their-checks). The first key set comes in step R1 of [Roll out kagent and agentgateway](roll-out-kagent-and-agentgateway.md). To remove the access, refer to [Roll back kagent and agentgateway](roll-back-kagent-and-agentgateway.md).

Each new cluster has new signing keys. Until you do these steps, the model calls fail with a Google authentication error. The Argo CD Applications stay `Synced` and `Healthy`.

## Before you start

- `kind-local` runs on this laptop. Your kubeconfig points to it.
- You know the name of this laptop on the allowlist, for example `personal` or `work`.
- `vertex:jwks` needs no Google credential. An agent can do steps 1 to 3.
- Only you do steps 4 to 6, outside of agent sessions.

## Steps

1. Bring up the cluster:

   ```sh
   mise run instance:up kind-local
   ```

2. Write the key file of this laptop:

   ```sh
   mise run vertex:jwks kind-local <laptop>
   ```

   The task reads `kubectl get --raw /openid/v1/jwks` and writes `accounts/gcp/jwks/<laptop>.json`. It replaces only the keys of this laptop.

3. Open a PR with that file only. A JWKS PR changes exactly one file under `accounts/gcp/jwks/`. `mise run lint` checks the combined set.
4. On the same laptop, compare the file in the PR with the live cluster:

   ```sh
   mise run vertex:jwks kind-local <laptop> --check
   ```

   It must exit with 0. If it fails, do not merge.

5. Merge the PR.
6. Apply `accounts/gcp/` in one apply session. Sign in, apply, then sign out.

   The plan must change only `oidc.jwks_json`. If it changes more, stop and read the plan.

7. If kagent and agentgateway are installed, send a question to the agent, as in done criterion 5 of the reference page. The model call must succeed.

## When the task stops

| Message or failure | Cause | Action |
| --- | --- | --- |
| The `server` is not a loopback address, or the kubeconfig has an `exec` or a `proxy-url` | The kubeconfig does not point to the local kind cluster. | Use the kubeconfig of `kind-local`. |
| "one `kind-local` at a time for the federation" | The issuer of the live cluster differs from `accounts/gcp/jwks/issuer.txt`. | Use the federation from one laptop only. Refer to [Open checks](../reference/kagent-and-agentgateway.md#open-checks). |
| `--check` exits non-zero | The file differs in a JWK member from the live cluster. | Do not merge. |
| The lint script fails | An unknown file name, a forbidden JWK member (for example `d`), no `use: sig`, more than 8 keys, or a repeated `kid`. | Correct the file. Never commit a private key member. |
| The plan fails on the `precondition` | More than 8 keys, or two keys with the same `kid`. | Do not apply. Correct the files in a PR. |

## Revoke the keys of one laptop

An agent can open the PR. Only you merge and apply, outside of agent sessions.

1. Remove `accounts/gcp/jwks/<laptop>.json` in a PR.
2. Merge the PR.
3. Apply `accounts/gcp/` in one apply session. Sign in, apply, then sign out.
