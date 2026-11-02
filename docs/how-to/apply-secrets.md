# Apply the secrets

This page tells you how to change a secret value and apply the secrets of an instance with `mise run secrets:apply`. It also has the rollout of the secrets design. The rules are in [Secrets (reference)](../reference/secrets.md). The reasons are in [Secrets management (explanation)](../explanation/secrets-management.md).

Agents never do these steps. Do them by hand, outside of agent sessions.

For the legacy Sealed Secrets on `olympus`, refer to [Manage secrets (legacy)](manage-secrets.md).

## Before you start

- The tooling PR is merged: `sops`, `age`, `.sops.yaml` and the `secrets:*` tasks exist.
- Your age scope key is in `keys.txt`, or on your hardware key.
- The cluster is up, and the seed namespace of each consumer in the seed map exists.

## Change a secret value

1. Stop all agent sessions.
2. Run `mise run secrets:edit <instance>`.
3. Change the value in the editor, then save and close it.
4. Commit the SOPS file. Git holds only the ciphertext.
5. Apply the secrets. Refer to the next procedure.

## Apply the secrets

1. Stop all agent sessions.
2. Read each diff since your last apply under `instances/`, `modules/` and `.mise/`.
3. Also read the diffs of the mise configuration and of each `.terraform.lock.hcl` file.
4. Run `mise run secrets:apply <instance>`.
5. If the task stops on a precondition, correct the cause and run it again.
6. Run `kubectl -n <consumer> get externalsecret`.
7. Make sure that each `ExternalSecret` has the `Ready` condition.

The task stops when the cluster is down, when a seed namespace is missing, or when the kubeconfig fails its checks. The kubeconfig fails when its `server` is not a loopback address, or when it has an `exec` or a `proxy-url`.

## After a re-create of the cluster

An agent can run `instance:down` and `instance:up`. The new cluster has no seeds, but the secrets state still lists them.

1. Wait for the message of the agent, or look at the `Ready` condition of each `ExternalSecret`.
2. Do [Apply the secrets](#apply-the-secrets). The plan creates each seed again with `data_wo`.
3. An agent runs `mise run vertex:jwks` and opens a PR with the new public keys. Refer to [Generate the Vertex JWKS](generate-vertex-jwks.md).
4. Review and merge that PR, then apply `accounts/gcp/`.

## Rotate a key or a value

| Event | Steps |
| --- | --- |
| A new recipient | Add the public key to the rule, then `sops updatekeys <file>`. |
| A recipient leaks or goes away | Remove it from the rule, `sops updatekeys <file>`, then `sops rotate --in-place <file>`, in this order. Then rotate each value at its issuer. |
| Planned data key rotation | `sops rotate --in-place <file>` once a year. |
| A value shows in the output of an agent | Rotate the value at its issuer, then do [Change a secret value](#change-a-secret-value). |
| SC1 finds a value in a PR | Rotate the value at its issuer, then clean the PR. |

Test the recovery key each year on the offline system.

## Go back

1. Delete the `ExternalSecret`. ESO deletes the consumer Secret.
2. Run `terraform destroy` on the secrets root module. This deletes the seeds.
3. Keep the SOPS file, if you want.

## Roll out the secrets design

Each step keeps `main` green. Do the steps in this order.

1. **Kind PR, a prerequisite.** Move `kind-local` to a Kubernetes 1.37 `kindest/node` image with a digest, and the matching `kind` version. Stop if no such image exists, and get a decision.
2. **Tooling PR.**
   1. Pin `sops` and `age`.
   2. Add `.sops.yaml` with public keys only.
   3. Make the recovery key on a machine that no agent uses, or on an offline live system.
   4. Make the `kind-local` scope key.
   5. Add `secrets:edit`, with the editor settings.
   6. Add `secrets:apply`, with its clean environment and preconditions.
   7. Add `secrets:rotate`.
3. **`bootstrap-cert-manager` PR.** Remove the token variable and `secret.tf`. The module takes the name of a Secret that ESO writes in `cert-manager`. After it, no file on `main` breaks SC10 or SC12.
4. **Enforcement and ESO PR, before any secret.**
   1. Add SC1, SC3 to SC13, SC15 and SC16, with tests.
   2. Add `policy/data/secrets.yaml` and `.gitleaks.toml`.
   3. Create the policy for SC11 if it is not on `main`.
   4. Run SC1a.
   5. Add `gitops/infrastructure/external-secrets/` with the admission policy (SC9a) and an empty consumer list.
      - Add the K15 data entry `{component: external-secrets, pattern: "^secret-seeds-"}` to `policy/data/labels.yaml`, with a test that passes and a test that fails.
      - Add `secret-seeds-*` to `reserved_namespaces`.
      - Update the K15 row of [Labels and annotations](../reference/labels-and-annotations.md#checks).
   6. Add the component to `cluster.yaml`.
   7. Update [Policies](../reference/policies.md) and rule 4 of `AGENTS.md`.
   8. Check: the ESO pods are ready.
5. **Secrets root module PR.** Add `modules/bootstrap-secret-seeds/` and `instances/kind-local/secrets/`, with a **dummy** value for the first seed of `thunder`. Extend `instance-checks.sh`. Update the "Files of an instance" table of [Repository structure](../reference/repository-structure.md#files-of-an-instance) and the instance schema for the `secrets/` folder. This PR only adds the module. No seed namespace exists yet, so do not run `secrets:apply` here.
6. **M1.** Steps R2 and R3 of [Roll out kagent and agentgateway](roll-out-kagent-and-agentgateway.md) own these PRs and their split. M1 has no secret and no consumer.
   - Gate: SC16 passes on the rendered agentgateway and kagent components, with the rule for `agentgateway-system`.
   - Check: no Secret in `agentgateway-system` or `kagent` holds a model credential (done criteria 3 and 7 of [kagent and agentgateway (reference)](../reference/kagent-and-agentgateway.md)).
7. **M2 secrets.** Steps R3, R4 and R6 of [Roll out OpenChoreo](roll-out-openchoreo.md) own these steps. R3 adds `thunder`, the first consumer. R4 adds `openchoreo-control-plane`. R6 adds the tenant `sandbox` (`oc-sandbox` and `secret-seeds-oc-sandbox`).
   1. After R3, make sure that `secret-seeds-thunder` exists.
   2. Run `secrets:apply` with the dummy value.
   3. Do [the dummy test](#do-the-dummy-test).
   4. Put the real values in only after the dummy test passes.
   5. Check: `kubectl -n thunder get secretstore secrets` shows a valid store.
   6. Check: each `ExternalSecret` is in sync.
8. **Documentation PR.** Mark [Secret management (legacy)](../explanation/secret-management.md) and [Manage secrets (legacy)](manage-secrets.md) as legacy for `kubernetes/`, or rewrite them. Add "Add a secret" and "Rotate a secret".

### Do the dummy test

1. Run `mise run secrets:apply <instance>` with the dummy value.
2. Run `terraform plan -refresh-only -out=<file>`, then `terraform show -json <file>`.
3. Run `terraform apply -refresh-only`, then `terraform show -json`.
4. Search for the dummy and for its base64 form in the state and its backup.
5. Also search the saved plan and each output.

The test passes when no search finds the dummy.

### If the dummy test fails

The real values do not go into Terraform.

1. Delete the state and the plan file.
2. Keep the real key out of Terraform.
3. Create each seed by hand from the SOPS file, until a fix or the remote backend exists. For example:

```bash
sops decrypt --extract '["<seed>"]' <file> \
  | kubectl -n secret-seeds-<consumer> create secret generic <seed> --from-file=value=/dev/stdin
```
