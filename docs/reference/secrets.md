# Secrets (reference)

This page lists the stores, the seed namespaces, the consumers, the checks SC0 to SC16 and SC9a, the SOPS configuration, the age keys and the done criteria. The reasons are in [Secrets management (explanation)](../explanation/secrets-management.md). The steps are in [Apply the secrets](../how-to/apply-secrets.md) and [Add a secret consumer](../how-to/add-a-secret-consumer.md).

Most of these items do not exist on `main` yet. The rollout in [Apply the secrets](../how-to/apply-secrets.md#roll-out-the-secrets-design) adds them. The legacy tree `kubernetes/` on `olympus` keeps Sealed Secrets: refer to [Manage secrets (legacy)](../how-to/manage-secrets.md).

## Paths

| Path | Content |
| --- | --- |
| `instances/<instance>/secrets/secrets.sops.yaml` | The SOPS file of the instance. SOPS encrypts each value and keeps the map keys in plain text. |
| `instances/<instance>/secrets/` | The secrets root module, with its own local state. |
| `modules/bootstrap-secret-seeds/` | The child module that writes the seeds. It uses only `hashicorp/kubernetes`. |
| `gitops/infrastructure/external-secrets/` | The ESO component. |
| `.sops.yaml` | The SOPS creation rules, at the root. |
| `policy/data/secrets.yaml` | The trusted platform components, the SC7 exceptions and the namespaces of the SC16 workload rule. |
| `.gitleaks.toml` | The gitleaks rules, also SC3. |
| `.mise/tasks/secrets/apply.sh` | The `secrets:apply` task. |

## The secrets root module

An instance folder can hold one secrets root module, `instances/<instance>/secrets/`. This changes the instance rules of [Repository structure](repository-structure.md).

| File | Necessary | Content |
| --- | --- | --- |
| `terraform.tf` | Yes | The `terraform` block, with the `carlpett/sops` and `hashicorp/kubernetes` providers |
| `providers.tf` | Yes | `provider "kubernetes"` with `config_path` only |
| `main.tf` | Yes | `ephemeral "sops_file"` and `module "secret_seeds"` with the seed map |
| `.terraform.lock.hcl` | Yes | The provider checksums |
| `secrets.sops.yaml` | Yes | The SOPS file |

- It has no `instance.yaml`. It inherits `purpose` and `state.backend` from the `instance.yaml` of its parent. Thus the schema rule on `state.backend` and SC11 apply to it through the parent.
- `instance-checks.sh` checks the folder too.
- Only `mise run secrets:apply <instance>` runs Terraform in it, by hand, outside of agent sessions, after the review of the diffs.
- The instance root module never reads the SOPS file. `mise run instance:up` does not touch the seeds.

### The preconditions of `secrets:apply`

- The cluster is up.
- Its kubeconfig passes the checks of the [clean environment](#the-clean-environment-of-secretsapply).
- The seed namespace of each consumer in the seed map exists.

Else the task stops with a clear message.

### The clean environment of `secrets:apply`

- The task builds its own environment, so the review of `.mise/tasks/secrets/apply.sh` covers it.
- It runs Terraform with a minimal environment and `TF_CLI_CONFIG_FILE` set to an empty file of the repository.
- It uses a new `TF_DATA_DIR`, with `terraform init` against the lock file.
- It writes a temporary kubeconfig from `kind get kubeconfig --name <cluster>`.
- It stops if the `server` is not a loopback address, or if the file has an `exec` or a `proxy-url`.

### The review before each `secrets:apply`

The review reads each diff since the last apply under `instances/`, `modules/`, `.mise/`, the mise configuration and the `.terraform.lock.hcl` files.

## Terraform rules

1. **No secret in Terraform, if possible.** A secret that a cluster uses goes through a seed namespace and ESO. A module that needs a secret, for example `bootstrap-cert-manager`, gets the name of a Secret that ESO writes. It holds no secret.
2. **Ephemeral input.** Read a SOPS file only with the `carlpett/sops` ephemeral resource `sops_file` (version 1.4.1, [registry](https://registry.terraform.io/providers/carlpett/sops/1.4.1/docs)), only in a secrets root module. Terraform does not store ephemeral resources in state or plan files ([HashiCorp: manage sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)).
3. **Write-only output.** The value goes only into a write-only argument, for example `data_wo` of `kubernetes_secret_v1`, which provider 3.1.0 has ([registry](https://registry.terraform.io/providers/hashicorp/kubernetes/3.1.0/docs/resources/secret_v1)). Write-only arguments need Terraform 1.11. The repository uses 1.17.0.
4. **No `data "sops_file"`.** Its result goes into the state. The provider documentation warns: "To prevent plaintext secrets from being written to disk, you *must* use a secure remote state backend."
5. **Ephemeral variables.** A secret variable has `sensitive = true` and `ephemeral = true`.
6. **No resource that makes a secret, in local state** ([Provider accounts](provider-accounts.md)). That list already has `google_service_account_key`. M1 needs no Google key resource, because it uses federation.
7. **A fixed path for the decrypted values.** Refer to SC15.

`data_wo_revision` must change to push a new value, because Terraform does not see a write-only value. The revision comes from the hash of the encrypted file, which changes after each `sops edit`.

`secrets:apply` replaces each seed on each run. Thus each run corrects a hand edit of a seed, which Terraform cannot detect.

## SOPS and age

### Tools

| Tool | Version | Pin |
| --- | --- | --- |
| `sops` | Latest release on 2026-11-02: `v3.13.3` ([SOPS releases](https://github.com/getsops/sops/releases)) | `.mise/config.toml` |
| `age` | Exact version, set in the tooling PR | `.mise/config.toml` |
| `carlpett/sops` provider | 1.4.1 | `.terraform.lock.hcl` |
| `hashicorp/kubernetes` provider | 3.1.0 | `.terraform.lock.hcl` |

### `.sops.yaml`

`.sops.yaml` at the root has one creation rule for each SOPS file. SOPS uses the first rule that matches. It looks for `.sops.yaml` from the working folder ([SOPS: configuration file](https://github.com/getsops/docs/blob/main/content/en/docs/usage/identities/config-file/_index.md)), so the mise tasks run `sops` from the root.

- Each `path_regex` starts with `^` and ends with `$`, and matches one file, for example `^instances/kind-local/secrets/secrets\.sops\.yaml$`.
- Each rule has the scope key and the recovery key.
- No rule without a `path_regex`.
- The file holds public keys only.

### The age keys

| Key | Count | Where the private key is | Recipient of |
| --- | --- | --- | --- |
| Scope key | One for each SOPS file, first `kind-local` | `keys.txt` on the operator machine only. A hardware key through an age plugin before any production value. | Its one SOPS file |
| Recovery key | One | Offline, for example printed. Created on a machine that no agent uses, or on an offline live system. | Each SOPS file |

- No SSH recipients. Without another key, SOPS reads `~/.ssh/id_ed25519` and `~/.ssh/id_rsa` to decrypt ([SOPS: age](https://github.com/getsops/docs/blob/main/content/en/docs/usage/identities/age/_index.md)).
- No PGP.
- SOPS reads the scope key from `keys.txt` in `$XDG_CONFIG_HOME/sops/age/`, or on macOS in `$HOME/Library/Application Support/sops/age/`. `SOPS_AGE_KEY_FILE`, `SOPS_AGE_KEY` and `SOPS_AGE_KEY_CMD` change this. SOPS supports age plugins and age identities with a passphrase ([SOPS changelog](https://github.com/getsops/sops/blob/main/CHANGELOG.md)).
- No cluster holds an age key, so an age key rotation needs no change in a cluster.
- The recovery key gets a test each year on the offline system.

### Rotation

| Event | Steps |
| --- | --- |
| A new recipient | Add the public key to the rule, then `sops updatekeys <file>`. |
| A recipient leaks or goes away | Remove it from the rule, `sops updatekeys <file>`, then `sops rotate --in-place <file>`, in this order. Then rotate each value at its issuer. |
| Planned data key rotation | `sops rotate --in-place <file>` once a year. |
| A value changes | `mise run secrets:edit <instance>`, then `mise run secrets:apply <instance>`. |
| A scope key is lost | Decrypt with the recovery key, make a new scope key, then do the "recipient leaks" steps. |
| Both keys are lost | Create each value again at its issuer. |

Source: [SOPS: key management](https://github.com/getsops/docs/blob/main/content/en/docs/usage/key-management/_index.md).

### `secrets:edit`

- No agent session runs during the edit.
- The task sets an editor with swap, backup and undo files off.

## Mise tasks

| Task | Use | Who runs it |
| --- | --- | --- |
| `secrets:edit <instance>` | Opens the SOPS file in an editor. | By hand, outside of agent sessions |
| `secrets:apply <instance>` | Applies the secrets root module in the clean environment. | By hand, outside of agent sessions |
| `secrets:rotate` | Rotates the keys of a SOPS file. | By hand, outside of agent sessions |
| `lint:secrets` | Runs gitleaks on the commits of the PR, SC4 and SC5. Part of `mise run lint`. | Each person, CI |
| `instance:up`, `instance:down` | Bring an instance up and down. They do not touch the seeds. | Each person, also agents |

## Stores and seed namespaces

### Seed namespaces

| Name | Content | Created by |
| --- | --- | --- |
| `secret-seeds-<consumer>` | The seeds of one consumer only. No pod runs in it. | The `external-secrets` component, from its consumer list |
| `secret-seeds-oc-<tenant>` | The seeds of one OpenChoreo tenant, and its ServiceAccount `eso-seed-reader` | The `external-secrets` component, from its tenant list |

- Pod Security `restricted`, with the keys of [Labels and annotations](labels-and-annotations.md).
- The `tenant` label is `platform`, as K5 requires for an `infrastructure` component.
- The `external-secrets` component may own `Namespace` objects that match `^secret-seeds-`. This is an exception to K15.

### Seeds

- A seed is a Secret named after its remote key, for example `oauth-client-secret`.
- It has one data key, `value`.
- Each `ExternalSecret` sets `remoteRef.property: value`. Without `property`, the `kubernetes` provider will "json encode all key/value pairs" ([ESO: Kubernetes provider](https://external-secrets.io/latest/provider/kubernetes/)).

### Consumer store: `SecretStore` `secrets`

| Field or object | Value |
| --- | --- |
| Kind and name | `SecretStore` `secrets`, in the namespace of the consumer |
| Provider | ESO `kubernetes` |
| `remoteNamespace` | `secret-seeds-<consumer>`, set explicitly, because its default is `default` |
| Auth | The ServiceAccount `eso-seed-reader` in the namespace of the consumer |
| `RoleBinding` in `secret-seeds-<consumer>` | Gives `<consumer>/eso-seed-reader` `get`, `list` and `watch` on `secrets`, and `create` on `selfsubjectrulesreviews` |
| Rendered by | The store and its ServiceAccount: the component of the consumer, from a shared template. The seed namespace, `Role` and `RoleBinding`: the `external-secrets` component. |

A namespace that can use a store gets every seed that the store reads. A binding to a ServiceAccount that does not exist yet is valid.

### OpenChoreo store: `ClusterSecretStore` `oc-<tenant>`

One store for each OpenChoreo tenant. A tenant is its OpenChoreo namespace, and its name is a DNS label without `-` ([OpenChoreo platform](openchoreo-platform.md)).

| Field | Value |
| --- | --- |
| `metadata.name` | `oc-<tenant>` |
| `provider.kubernetes.remoteNamespace` | `secret-seeds-oc-<tenant>` |
| `auth.serviceAccount.name` | `eso-seed-reader` |
| `auth.serviceAccount.namespace` | `secret-seeds-oc-<tenant>`. Without it, ESO uses "referent" auth. |
| `spec.conditions` | Exactly one entry: `namespaceRegexes: ["^dp-<tenant>-"]`. No label condition. |
| Token `Role` | The `Role` of `rbac.serviceAccountTokenCreate: false` names `secret-seeds-oc-<tenant>/eso-seed-reader`. |

- No other `ClusterSecretStore`, and no `ClusterExternalSecret`. SC9 checks this in Git, SC9a in the cluster.
- Before a second tenant, the OpenChoreo cluster agent must lose `clustersecretstores` and the RBAC kinds (question 13 B of the [OpenChoreo platform](openchoreo-platform.md)). Until then, M2 has one test tenant only.

## Consumers

| Consumer | Store | Secrets | Added by |
| --- | --- | --- | --- |
| `thunder` | `SecretStore` `secrets` | ThunderID and OAuth client secrets | Step R3 of [Roll out OpenChoreo](../how-to/roll-out-openchoreo.md) |
| `openchoreo-control-plane` | `SecretStore` `secrets` | Backstage and OAuth client secrets | Step R4 of [Roll out OpenChoreo](../how-to/roll-out-openchoreo.md) |
| `cert-manager` | `SecretStore` `secrets` | The Cloudflare token, when an instance uses the DNS-01 solver | The instance that uses DNS-01 |
| Tenant `sandbox` | `ClusterSecretStore` `oc-sandbox`, `secret-seeds-oc-sandbox` | A test seed | Step R6 of [Roll out OpenChoreo](../how-to/roll-out-openchoreo.md) |

Not consumers:

- M1 has no consumer.
- `agentgateway-system`: agentgateway calls Vertex AI through federation. It becomes a consumer only with the fallback of question 14 of [kagent and agentgateway](kagent-and-agentgateway.md).
- `kagent`: it gets no store, because its controller can write in `kagent`.

A PR adds a consumer to the consumer list only together with the component of that consumer. SC9 checks both directions.

## The ESO component

`gitops/infrastructure/external-secrets/` installs the upstream chart from `https://charts.external-secrets.io` ([ESO: getting started](https://external-secrets.io/latest/introduction/getting-started/)) with an exact version.

- Version: ESO 2.14, the latest minor on 2026-11-02. It lists Kubernetes 1.37 ([ESO: stability](https://external-secrets.io/latest/introduction/stability-support/)). `kind-local` uses a Kubernetes 1.37 `kindest/node` image.
- Its values hold the consumer list and the tenant list.
- For each consumer, it renders the seed namespace, the `Role` and the `RoleBinding`.
- For each tenant, it renders the seed namespace, its ServiceAccount, its RBAC and the `oc-<tenant>` store.
- It renders the `ValidatingAdmissionPolicy` of SC9a and its binding.
- The CRDs get the wave `-1`.

Chart values, after [ESO: security best practices](https://external-secrets.io/latest/guides/security-best-practices/):

| Value | Setting | Effect |
| --- | --- | --- |
| `processPushSecret`, `processClusterPushSecret`, `processClusterExternalSecret` | `false` | ESO cannot copy a Secret out. This also blocks the managed secret API of OpenChoreo. |
| `processClusterStore` | `true` | For the `oc-*` stores only |
| `rbac.serviceAccountTokenCreate` | `false` | A `Role` with `resourceNames` permits a token only for each `eso-seed-reader` |
| `rbac.aggregateToEdit`, `rbac.aggregateToView`, `rbac.aggregateToAdmin` | `false` | Only Argo CD creates ESO objects |
| Network policy | None yet | A default-deny policy waits for the zero-trust design |

## Trusted platform components

`policy/data/secrets.yaml` lists each component with its chart version and instance. The residual risk of each row is accepted on `kind-local`. Upstream patches that narrow these roles are follow-ups.

| Component | Access | Narrowing |
| --- | --- | --- |
| ESO controller | `get`, `list`, `watch`, `create`, `update`, `patch`, `delete` on `secrets` in all namespaces | None in the chart, except `scopedRBAC`, which turns off the `oc-*` cluster stores |
| agentgateway controller (v1.7.0) | Reads Secrets in all namespaces. With federation, no model key exists for it to read. Its deployer can run a pod as the proxy `ServiceAccount`, which has the Google identity. | `rbac.gatewayNamespaces` limits only its writes |
| OpenChoreo cluster agent | `*` on `secrets`, `clustersecretstores` and RBAC kinds (upstream) | Question 13 B of the [OpenChoreo platform](openchoreo-platform.md) |
| OpenChoreo control plane: controller manager, API, cluster gateway (upstream 1.3.3) | `get` and `list` on `secrets` in all namespaces. The controller manager also `watch`. | Where their charts permit. This waits for the OpenChoreo work. |
| kagent controller | Reads all core resources in all namespaces (chart 0.10.4) | `rbac.namespaces: [kagent]` (question 5 A of [kagent and agentgateway](kagent-and-agentgateway.md)). This row applies only if a later change makes it cluster-wide again. |
| Argo CD application controller and `argocd-server` | Their default cluster-wide roles. `argocd-server` has `get`, `patch` and `delete` on all resources (chart 10.11.6, on `main`). | Where their chart permits |
| cert-manager controller, when an instance installs it | Reads and writes the Secrets of certificates in the namespaces that it serves | Where its chart permits |

The stores isolate the consumers from each other, not from these controllers.

## Requirements on kagent

[kagent and agentgateway (reference)](kagent-and-agentgateway.md) holds the kagent values. They must meet these requirements:

- Pin the kagent chart to an exact version.
- Never set `providers.*.apiKey`. The chart then renders a Secret with the key into `rendered/`. SC7 refuses it.
- `kagent-tools`: `rbac.readOnly: true` and `rbac.allowSecrets: false`.
- The kagent controller: `rbac.namespaces: [kagent]` (question 5 A). The chart then renders a getter and a writer `Role` with `""/*` in `kagent` only. SC16 permits these two roles there, by name.
- kmcp: off in M1 (`kmcp.enabled: false`, question 8 A). If it comes later, `kmcp.rbac.namespaces: [kagent]`.
- The auth mode of the controller: question 13 of the kagent design. A `NetworkPolicy` and checks now, the principals of kagent v1.0 later.
- No key in `kagent`. No `ModelConfig` refers to a model key. If the agent runtime needs a value, question 16 of the kagent design holds the options. A dummy Secret with data then needs a new SC7 exception, which only a decision outside of agent sessions can add.

## Checks

| ID | Check | Tool | Rule | Level |
| --- | --- | --- | --- | --- |
| SC0 | Push protection | GitHub (exists, on) | Refuses a push with a turned-on pattern. The non-provider patterns are on (question 6). Writers can bypass it. | Server |
| SC1 | Secret scan in CI | New `lint:secrets` in `mise run lint` | gitleaks scans the commits of the PR. `lint.yml` installs gitleaks and gets the full branch history. A hit means: rotate the value at its issuer, then clean the PR. | Fail |
| SC1a | Full history | `gitleaks git`, one time | Scan all the history. A hit means a rotation. | One time |
| SC2 | Before the commit | pre-commit `gitleaks`, `detect-private-key` (exist) | Unchanged. | Fail |
| SC3 | age private key | `.gitleaks.toml` | Refuse `AGE-SECRET-KEY-1` and `keys.txt`. | Fail |
| SC4 | SOPS file encrypted | `lint:secrets` | `sops filestatus` gives `{"encrypted":true}` for each `*.sops.yaml`. | Fail |
| SC5 | SOPS recipients | `lint:secrets` | The recipients of each file equal its rule in `.sops.yaml`. | Fail |
| SC6 | `.sops.yaml` shape | Conftest `sops` | Anchored `path_regex`, the recovery key, no rule without `path_regex`. | Fail |
| SC7 | No Secret data in `gitops/` | Conftest `kubernetes` | No values in `data` or `stringData`, also when encrypted. `kubernetes/` keeps the current rule. One exception: in `gitops/clusters/kind-local/rendered/kagent/`, the `Secret` `kagent-postgresql` with the one key `POSTGRES_PASSWORD` and the value `a2FnZW50`, the base64 form of the chart constant `kagent` (question 9 A of the kagent design). `policy/data/secrets.yaml` lists it with that path, and the check compares the exact value. A second exception for a dummy `ModelConfig` key needs a decision (question 16 of the kagent design). | Fail |
| SC8 | No Sealed Secrets in `gitops/` | Conftest `kubernetes` | No `kind: SealedSecret`. | Fail |
| SC9 | ESO objects | Conftest `kubernetes` | Refer to [SC9 rules](#sc9-rules). | Fail |
| SC9a | `ClusterSecretStore` in the cluster | `ValidatingAdmissionPolicy` | The SC9 rules for `ClusterSecretStore`, at admission: a name `oc-<tenant>`, the `remoteNamespace` and the ServiceAccount namespace equal to `secret-seeds-` plus the name, and exactly the one regex condition. | Deny |
| SC10 | Terraform secrets | Conftest `terraform` | No `data "sops_file"`. No values in `data` or `binary_data` of `kubernetes_secret_v1`. Each `data_wo` has a `data_wo_revision`. | Fail, after the change of `bootstrap-cert-manager` |
| SC11 | Secret resources in local state | Conftest `terraform` | The policy of [Provider accounts](provider-accounts.md), created if it is not on `main`. Its list has `google_service_account_key`. It also covers each secrets root module, through its parent `instance.yaml`. | Fail |
| SC12 | Secret variables | Conftest `terraform` | `sensitive = true` also has `ephemeral = true`. | Fail, after the change of `bootstrap-cert-manager` |
| SC13 | No CI secrets | Conftest `actions` | No `secrets.<name>` except `GITHUB_TOKEN`, no `secrets: inherit`, no `toJSON(secrets)`. | Fail |
| SC14 | Required check | Ruleset on `main` (exists) | `Run every linter and check` is required. | Exists |
| SC15 | The path of the decrypted values | Conftest `terraform`, `--combine` | Refer to [SC15 rules](#sc15-rules). | Fail |
| SC16 | RBAC of Secrets and workloads | Conftest `kubernetes` on `gitops/**/rendered/` | Refer to [SC16 rules](#sc16-rules). | Fail |

Each Conftest rule has a test for a pass and a fail case. SC7 changes the current rule of [Policies](policies.md): a SOPS-encrypted `Secret` no longer passes in `gitops/`, because no SOPS file goes there.

Before the push, only SC2 prevents a leak. At the push, only SC0 prevents it. SC1 only detects.

### SC9 rules

- An `ExternalSecret` refers to `SecretStore` `secrets`, or to `ClusterSecretStore` `oc-<tenant>` from a cell of that tenant.
- Each `remoteRef` has `property: value`.
- No `dataFrom.find`.
- A `SecretStore` sets `remoteNamespace` to the seed namespace of its own namespace.
- A `ClusterSecretStore` has the name `oc-<tenant>`. Its `remoteNamespace` and `auth.serviceAccount.namespace` equal `secret-seeds-oc-<tenant>`. It has exactly one condition `namespaceRegexes: ["^dp-<tenant>-"]`.
- No `ClusterExternalSecret`, `PushSecret` or `ClusterPushSecret`.
- A `RoleBinding` in `secret-seeds-<c>` binds only the store ServiceAccount of `<c>`.
- Each consumer in the consumer list has a store `secrets` and a ServiceAccount `eso-seed-reader` in its own component. Each store has a consumer.

### SC15 rules

- Only `instances/<instance>/secrets/main.tf` refers to `ephemeral.sops_file`, and only as an input of `module.secret_seeds`.
- No `local` refers to `ephemeral.*`.
- No `provisioner` and no `action` block in the secrets root module or in a module with an ephemeral variable.
- In such a module, an ephemeral variable goes only into a listed write-only argument. The module has no `provider` block and no `ephemeral` block.
- `module.secret_seeds` has no `providers` argument.
- `bootstrap-secret-seeds` uses only `hashicorp/kubernetes`.
- The `provider "kubernetes"` block of the secrets root module has only `config_path`, set to the file that the task makes.

### SC16 rules

SC16 reads each `Role`, `ClusterRole`, `RoleBinding` and `ClusterRoleBinding`, also the bindings to built-in roles such as `cluster-admin`, `admin` and `edit`. A rule matches `secrets` also through `resources: ["*"]` or `apiGroups: ["*"]`.

- Only a trusted platform component of `policy/data/secrets.yaml`, at its chart version and instance, has read access to Secrets in all namespaces.
- No role of the kagent tool server has `*`, `secrets` or `nonResourceURLs`.
- The kagent getter and writer `Role` with `""/*` are permitted in `kagent` only, by name.
- Outside the allowlist, no ServiceAccount gets these rights in a protected namespace: `create`, `update` or `patch` on pods or workload kinds (`deployments`, `statefulsets`, `daemonsets`, `replicasets`, `jobs`, `cronjobs`), `create` on `serviceaccounts/token`, `pods/exec`, the RBAC kinds, or `impersonate`.
- A protected namespace holds a seed, a consumer Secret, or a `ServiceAccount` with a federated Google identity. For M1 that is `agentgateway-system`. `policy/data/secrets.yaml` lists these namespaces.
- For this rule, the allowlist is the same file: each trusted platform component with its chart version and instance, by its role and binding. For `agentgateway-system`, that is the deployer `RoleBinding` of the agentgateway controller and the roles of Argo CD.

## CI secrets

- No repository secret, no environment secret, and no long-lived cloud key in GitHub Actions.
- The workflows need only `GITHUB_TOKEN` with `contents: read`.
- A later cloud job uses GitHub OIDC with Workload Identity Federation ([Google Cloud: federation with deployment pipelines](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)).

## Agent rules

- Never run `sops decrypt`, `sops edit`, `sops exec-env`, `kubectl get secret -o yaml`, `secrets:apply`, or any `terraform` command in `instances/*/secrets/`. Never read `keys.txt` or a `.tfstate` file, and never delete one.
- Never run `kubectl create token` for the proxy `ServiceAccount` of `agentgateway-system`, and never read its token file. Never run a `terraform` command in `accounts/`, never edit `accounts/gcp/jwks/` by hand, and never merge a PR that touches `accounts/`. Agents may run `vertex:jwks`: it writes public keys to a file in a PR ([Generate the Vertex JWKS](../how-to/generate-vertex-jwks.md)).
- `mise run instance:up` and `instance:down` stay permitted. After a re-create of a cluster with seeds, tell the operator.
- No agent session runs during the edit of a SOPS file or during `secrets:apply`.
- Write the code around a secret, never the value. If a value shows in the output of an agent, rotate it.

These are rules, not controls. Only the agent identity design closes the gap.

## Done criteria

```text
1. No Secret in Git has data that is not encrypted.
   Check: `mise run lint:policy` passes in CI.
2. No commit of a PR adds a secret.
   Check: `mise run lint:secrets` runs gitleaks in CI.
3. No state holds a secret value.
   Check: the dummy test of the M2 secrets step in "Apply the secrets".
4. The first consumer on kind-local reads its seeds from ESO.
   Check: `kubectl -n thunder get externalsecret` shows each Secret in sync.
5. Only the trusted platform components read Secrets cluster-wide.
   Check: SC16 passes in CI.
6. M1 holds no model key.
   Check: done criteria 3, 7 and 9 of "kagent and agentgateway (reference)".
```

## Open checks

A later spike or the implementation PR settles these items.

- **Kind.** A `kindest/node` image for Kubernetes 1.37 exists for the selected `kind` version. The kind release notes are on `github.com/kubernetes-sigs`, which is not a permitted domain. If none exists, a decision is necessary.
- **SOPS.** It refuses a file that matches no rule. The `filestatus` output in 3.13.3. The ephemeral resource reads `SOPS_AGE_KEY_FILE`, `SOPS_AGE_KEY_CMD` and age plugins, and how it fails without a TTY. The provider example writes `data.sops_file` for the ephemeral resource; use `ephemeral.sops_file`. The editor of `secrets:edit` and its settings.
- **Terraform.** A module variable that is ephemeral feeds `data_wo` through `for_each`. `data_wo_revision = parseint(substr(filesha256(<file>), 0, 8), 16)` is valid. A refresh does not fill `data` when only `data_wo` is set; the 3.1.0 page still says "All arguments including the secret data will be stored in the raw state as plain-text". The provider drops a Secret from the state on a 404, and a create sends `data_wo` also when `data_wo_revision` did not change. `-replace` of each seed on each run. An `action` block can or cannot read an ephemeral value. SC15 can find each reference with the HCL parser of Conftest, which gives expressions as strings.
- **The dummy test.** `secrets:apply`; `terraform plan -refresh-only -out=<file>` and `terraform show -json <file>`; `terraform apply -refresh-only`; `terraform show -json`. Search for the dummy and for its base64 form in the state, its backup, the saved plan and each output. The fallback, if a search finds it, is in [Apply the secrets](../how-to/apply-secrets.md#if-the-dummy-test-fails).
- **The secrets root module.** The schema and lint checks accept `instances/<instance>/secrets/`, and its inheritance of `state.backend`. The loopback and `exec` checks of the kubeconfig. An empty `TF_CLI_CONFIG_FILE` works.
- **ESO.** The store fields. A store ServiceAccount in the consumer namespace reads the seed namespace through a `RoleBinding` there. `createPushSecret` and `createClusterPushSecret` are under `crds.`, and each `crds.create*: false` needs the matching `process*: false`. `crds.createClusterExternalSecret: false` removes that CRD. `processClusterGenerator`. The forced refresh annotation and the status names. `deletionPolicy: Retain` keeps the consumer Secret when its seed goes away. The ESO Application syncs a store before its consumer namespace exists, or retries.
- **The admission policy.** The CEL expressions of SC9a for `ClusterSecretStore`. If the upstream OpenChoreo cluster agent role can change a `ValidatingAdmissionPolicy` or its binding.
- **Argo CD.** No `OutOfSync` on a Secret that ESO owns. `SkipDryRunOnMissingResource=true` on a store before the CRDs exist.
- **agentgateway.** The read role of the controller in v1.7.0, and `rbac.gatewayNamespaces`. [kagent and agentgateway (reference)](kagent-and-agentgateway.md) holds the open checks of the federation and its fallback.
- **kagent.** The parent value path `kagent-tools.rbac.*`. The names of the getter and writer `Role` with `rbac.namespaces: [kagent]`, and that the controller works with them and with `kagent.rbac.validate`. The auth value is `controller.auth.mode` in 0.10.4, and `config.server.auth.mode` on `main`.
- **OpenChoreo.** How a tenant selects its `oc-<tenant>` store, because `SecretStoreRef` has only a name. The values that narrow the Secret roles of the controller manager, the API and the cluster gateway.
- **kgateway 2.3.11 and ThunderID.** Their Secret roles. Their sources are not on a permitted domain.
- **The shared store template.** The library chart or template that each consumer component uses for `eso-seed-reader` and the store `secrets`.
- **GitHub.** Delegated bypass for push protection on this plan.
- **gitleaks 8.30.1.** The command for the commit range of a `pull_request` merge ref, and a built-in rule for age keys.
- **Costs not read.** AWS Secrets Manager prices and the KMS cost of an SSM `SecureString`. The Azure Key Vault free tier: community answers say 10,000 transactions a month for 12 months ([Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/5608202/how-to-correctly-estimate-azure-key-vault-cost)). The free tiers of Bitwarden, Infisical and 1Password. If Cloud KMS Autokey fits SOPS.

## Open decisions

The seven questions of this design are decided. Refer to [Secrets management (explanation)](../explanation/secrets-management.md). These items stay open:

- **The fallback if the federation fails in agentgateway** (question 14 of [kagent and agentgateway](kagent-and-agentgateway.md)). The recommendation there is a service account key in SOPS. Then `agentgateway-system` becomes a consumer, the key comes from `gcloud` (not Terraform: SC11), and the hardware key (question 3 c) comes first.
- **A dummy `ModelConfig` key for kagent** (question 16 of the kagent design). A dummy Secret with data needs a second SC7 exception.
- **A spend kill switch** (question 15 of the kagent design).
- **The changes to K15 and to the instance folder.** This design permits `^secret-seeds-` `Namespace` objects in the `external-secrets` component, and a secrets root module in an instance folder. [Labels and annotations](labels-and-annotations.md) (K15) and [Repository structure](repository-structure.md) do not have these exceptions yet. Options: change those pages in the PR that adds each item, or change them now. The recommendation of this design is that these exceptions apply.
