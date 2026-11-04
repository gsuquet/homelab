# Secrets

The secrets of the `gitops/` tree are in one SOPS file for each instance, encrypted with age. A secrets root module writes each value into a seed namespace, and External Secrets Operator (ESO) copies it into the namespace of its consumer. The legacy `kubernetes/` tree keeps Sealed Secrets on `olympus`.

| Path | Content |
| --- | --- |
| `.sops.yaml` | The SOPS creation rules: one rule for each SOPS file, public keys only. |
| `instances/<instance>/secrets/` | The secrets root module of an instance. Refer to [Secrets root module](#secrets-root-module). |
| `instances/<instance>/secrets/secrets.sops.yaml` | The SOPS file of the instance. |
| `modules/bootstrap-secret-seeds/` | The child module that writes the seeds. It uses only `hashicorp/kubernetes`. |
| `gitops/infrastructure/external-secrets/` | The ESO component. Refer to [ESO component](#eso-component). |
| `policy/data/secrets.yaml` | The trusted platform components, the SC7 exception and the SC16 protected namespaces and allowlist. |
| `.gitleaks.toml` | The gitleaks settings, with the SC3 rule for age keys. |
| `.mise/tasks/secrets/` | The scripts of the `secrets:*` tasks. `.mise/tasks/_base/secrets.sh` holds their checks and builds the clean environment. |

## Classes of secrets

| Class | Where the value is | Path to the consumer |
| --- | --- | --- |
| Kubernetes secrets, also the cert-manager DNS token | The SOPS file of the instance | Secrets root module, then seed namespace, then ESO |
| Terraform inputs | None. A module that needs a secret gets the name of a Secret that ESO writes. | None |
| Provider credentials | Not in the repository | Environment variables in one apply session |
| age keys | The scope key on the computer that applies the secrets. The recovery key offline. | None |
| ESO credentials | None on `kind-local` | None |
| CI secrets | None | None |
| Sealed Secrets on `olympus` | The Sealed Secrets controller | The legacy `kubernetes/` tree |

## SOPS file and keys

| Item | Value |
| --- | --- |
| SOPS file | `instances/<instance>/secrets/secrets.sops.yaml`, one for each instance |
| Encryption | age. No PGP, no SSH recipients, no cloud KMS. |
| Scope key | One age key for each SOPS file. On `kind-local`, a plain `keys.txt` file. |
| Recovery key | One age key, made on a machine that no agent uses or on an offline live system. Kept offline, for example on paper. A recipient of each SOPS file. |
| Keys in a cluster | None |

### Layout of the SOPS file

The SOPS file has one block for each consumer, and thus for each seed namespace. Each key of a block is the name of a seed:

```yaml
<consumer>:
  <seed>: <value>
```

The block of a namespaced consumer has the name of its namespace, for example `thunder`. The block of a tenant has the name `oc-<tenant>`. The block names are equal to the keys of the seed map.

### `.sops.yaml`

`.sops.yaml` is at the root of the repository.

- Each SOPS file has one creation rule.
- Each rule has a `path_regex` that starts with `^`, ends with `$` and matches one file, for example `^instances/kind-local/secrets/secrets\.sops\.yaml$`.
- Each rule has the scope key and the recovery key of its file.
- No rule is without `path_regex`.
- The file holds public keys only.

SOPS looks for `.sops.yaml` in the working folder, then in each parent folder. It matches `path_regex` against the file path relative to the folder of `.sops.yaml`. The mise tasks run `sops` from the root of the repository. SOPS refuses to encrypt a file that matches no rule, with `no matching creation rules found`.

### Key location

The scope key is in `keys.txt` in the SOPS user config folder: `$XDG_CONFIG_HOME/sops/age/` when `XDG_CONFIG_HOME` is set, else `$HOME/Library/Application Support/sops/age/` on macOS and `$HOME/.config/sops/age/` on other systems.

SOPS 3.13.3 does not choose one source of age keys. It reads each of these sources, and it tries each identity that it finds ([`age/keysource.go`, `loadIdentities` and `loadAgeSSHIdentities`](https://github.com/getsops/sops/blob/v3.13.3/age/keysource.go)):

| Source | Content |
| --- | --- |
| `SOPS_AGE_SSH_PRIVATE_KEY_FILE`, `SOPS_AGE_SSH_PRIVATE_KEY_CMD` | An SSH private key, or a command that prints it. |
| `~/.ssh/id_ed25519`, `~/.ssh/id_rsa` | The SSH keys of `HOME`, when they exist. |
| `SOPS_AGE_KEY` | One or more age keys. |
| `SOPS_AGE_KEY_FILE` | The path of an age key file. |
| `SOPS_AGE_KEY_CMD` | A command that prints age keys. |
| `keys.txt` in the user config folder | The age key file, when it exists. |

The `secrets:*` tasks thus give SOPS and Terraform a new, empty `HOME` in their temporary folder and one key file in `SOPS_AGE_KEY_FILE`. They pass no other `SOPS_AGE_*` variable of the shell, so a variable that the shell sets for another use, for example the age key of mise, has no effect.

| Variable of the tasks | Meaning |
| --- | --- |
| `HOMELAB_SOPS_AGE_KEY_FILE` | The path of the scope key file. When it is not set, the tasks use `keys.txt` in the user config folder. The task stops when the file does not exist. |

A SOPS file with production values uses a hardware key through an age plugin, with a touch for each decryption.

## Secrets root module

`instances/<instance>/secrets/` is a Terraform root module with its own local state.

| File | Content |
| --- | --- |
| `terraform.tf` | The `terraform` block, with `carlpett/sops` and `hashicorp/kubernetes`. |
| `providers.tf` | `provider "kubernetes"` with `config_path = var.kubeconfig_path` only. The tasks give the kubeconfig that they make with `-var=kubeconfig_path=<file>` on the plan command. A `-var` option wins over each variable file, and the saved plan keeps it for the apply. |
| `main.tf` | `ephemeral "sops_file"`, and `module "secret_seeds"` with the seed map in its `seeds` argument. The seed map is a literal map, because the tasks read its keys from the file. |
| `.terraform.lock.hcl` | The provider checksums. |
| `secrets.sops.yaml` | The SOPS file. |

- The folder has no `instance.yaml`. It gets `purpose` and `state.backend` from the `instance.yaml` of its parent instance. `instance-checks.sh` checks the folder.
- The instance root module never reads the SOPS file. `instance:up` and `instance:down` never change the seeds.
- Only a person runs Terraform in this folder, by hand, outside agent sessions, usually through `secrets:apply`.

### Terraform rules

1. A cluster secret goes through a seed namespace and ESO. A module that needs a secret takes the name of a Secret that ESO writes.
2. Only the `sops_file` ephemeral resource of `carlpett/sops` reads a SOPS file, only in a secrets root module.
3. A value goes only into a write-only argument, for example `data_wo` of `kubernetes_secret_v1`.
4. No `data "sops_file"`: Terraform stores its result in the state.
5. A secret variable has `sensitive = true` and `ephemeral = true`.
6. No resource that makes a secret in a local state, for example `google_service_account_key`.
7. The decrypted values go only along a fixed path. Refer to [SC15 rules](#sc15-rules).

### Seed map and revision

| Item | Value |
| --- | --- |
| Seed map | A non-ephemeral input of `module.secret_seeds`: each consumer and the names of its seeds. The key of a namespaced consumer is its namespace. The key of a tenant is `oc-<tenant>`, the name of its store. `for_each` uses this map. The decrypted map gives only the values. |
| Seed | A `kubernetes_secret_v1` named after its remote key, for example `oauth-client-secret`, in `secret-seeds-<consumer>`. One data key: `value`. |
| `data_wo_revision` | `parseint(substr(filesha256(<file>), 0, 8), 16)`, from the hash of the encrypted file. Each edit of the SOPS file changes the revision of each seed. |
| State | `data: null` and `data_wo: null` for each seed. No value, plain or base64, in the state, its backup or a plan. |

Terraform refuses a sensitive or an ephemeral value in `for_each`.

### Versions

| Item | Version | Pinned in |
| --- | --- | --- |
| Terraform | 1.17.0 | `.mise/config.toml` |
| `sops` | 3.13.3 | `.mise/config.toml` |
| `age` | 1.3.2 | `.mise/config.toml` |
| ESO chart `external-secrets` | 2.14.0 | `gitops/infrastructure/external-secrets/sources/Chart.yaml` |
| `carlpett/sops` | 1.4.1 | `.terraform.lock.hcl` |
| `hashicorp/kubernetes` | 3.1.0 | `.terraform.lock.hcl` |

A change to the version of `carlpett/sops` or `hashicorp/kubernetes` needs the state test again. Refer to [Check that the state holds no value](../how-to/apply-the-secrets.md#check-that-the-state-holds-no-value).

## Tasks

| Task | Use | Who runs it |
| --- | --- | --- |
| `secrets:edit <instance>` | Open the SOPS file of the instance in vim with no vimrc, no plugins, no viminfo and no modeline, and with swap, backup and undo files off. SOPS writes its temporary file into a new folder with mode `0700`. | A person, by hand, with no agent session |
| `secrets:plan <instance>` | Show the drift between the state and the cluster, as a saved refresh-only plan and its JSON, in the clean environment. It changes nothing in the cluster or the state. It does not show a hand edit of a seed value. | A person, by hand, with no agent session |
| `secrets:apply <instance>` | Apply the secrets root module of the instance in the clean environment. | A person, by hand, with no agent session |
| `secrets:destroy <instance>` | Destroy the secrets root module of the instance, and thus its seeds, in the clean environment. | A person, by hand, with no agent session |
| `secrets:rotate <instance> --recipients` | Run `sops updatekeys` on the SOPS file of the instance, after a change to its rule in `.sops.yaml`. | A person, by hand, with no agent session |
| `secrets:rotate <instance> --data-key` | Run `sops rotate --in-place` on the SOPS file of the instance. | A person, by hand, with no agent session |
| `lint:secrets` | Run SC1, SC4 and SC5. Part of `mise run lint`. | Anyone, also CI |
| `instance:up`, `instance:down` | Do not change the seeds. | Anyone, also agents |

A value change has no task of its own: `secrets:edit`, then `secrets:apply`.

### `secrets:plan`, `secrets:apply` and `secrets:destroy`

```bash
mise run secrets:plan <instance>
mise run secrets:apply <instance>
mise run secrets:destroy <instance>
```

| Task | Terraform commands |
| --- | --- |
| `secrets:plan` | `terraform plan -refresh-only -out=<plan-folder>/secrets.tfplan`, then `terraform show -json <plan-folder>/secrets.tfplan` |
| `secrets:apply` | `terraform plan -replace=<seed address> ... -out=<plan-folder>/secrets.tfplan`, then `terraform apply <plan-folder>/secrets.tfplan` |
| `secrets:destroy` | `terraform plan -destroy -out=<plan-folder>/secrets.tfplan`, then `terraform apply <plan-folder>/secrets.tfplan` |

- `<plan-folder>` is a new temporary folder outside the repository. Each task makes it with `mktemp -d` under `umask 077`, so its mode is `0700`. Terraform treats a saved plan file as a possible sensitive file.
- `secrets:plan` prints the path of its folder and keeps it. The folder holds the plan file and the JSON output, and the person who runs the task deletes it.
- `secrets:apply` and `secrets:destroy` delete their folder on each exit, through a `trap` on `EXIT`, `INT` and `TERM`: after a success, a refused confirmation, a failed apply or Ctrl-C.
- The mode `0700` protects the folder against other OS users only. An agent with the same OS user can read it. The plan file holds no value.
- `secrets:plan` needs the scope key, and it decrypts in memory like `secrets:apply`.
- `secrets:apply` and `secrets:destroy` do these steps in this order:
  1. Check the preconditions.
  2. Make the saved plan in a new temporary folder outside the repository.
  3. Print a summary of the plan, with no values: `terraform show -json` of the plan, restricted to `.resource_changes[].address` and `.change.actions`.
  4. Ask for a typed confirmation on the terminal: `apply <instance>` or `destroy <instance>`. Each other answer stops the task with no change, and with the exit status `1`. A plan with no change stops the task before the question, with the exit status `0`.
  5. Apply the saved plan. The `trap` then deletes the temporary folder.
- Terraform applies a saved plan with no prompt, because it takes the plan file as the approval ([`terraform apply`](https://developer.hashicorp.com/terraform/cli/commands/apply)). The typed confirmation of the task is thus the approval, after the review of the diffs.
- Each `secrets:*` task stops when the process has no terminal. `secrets:apply` and `secrets:destroy` read the confirmation from `/dev/tty`. This stops a run from a plain tool call, CI or a pipe, for example `yes |`. It does not stop a process that makes a pseudo-terminal, for example `script` or `expect`, and it does not stop a direct `terraform` command. The controls stay the agent rules, a scope key that agents do not get for production values, and a person who runs the task.

The three tasks have the same preconditions. A task stops with a message when one of them fails:

| Precondition | Check |
| --- | --- |
| The working tree is clean. | Git shows no change and no untracked file. |
| No ignored file can change the Terraform code. | `instances/<instance>/secrets/` and `modules/bootstrap-secret-seeds/` have no ignored file and no ignored folder, except the local state files `terraform.tfstate`, `terraform.tfstate.backup` and `.terraform.tfstate.lock.info`. Terraform loads ignored files, for example `*.tfvars`, `*.auto.tfvars`, `override.tf` and `*_override.tf`. |
| The commit is the tip of `main`. | The task runs `git fetch origin main`, and the checked-out commit is equal to the fetched commit. A task runs only after the merge, from the merged commit. A failed fetch stops the task. |
| The cluster is up. | The task gets a kubeconfig from the cluster with `kind get kubeconfig`, and `/readyz` of the API server answers. The cluster name is the `cluster_name` output of the instance root module. |
| The kubeconfig is clean. | The file has exactly one cluster. `server` is a loopback address: `https://` and `127.0.0.1`, `localhost` or `[::1]`. The file has only the keys that `kind get kubeconfig` writes: `server` and `certificate-authority-data` for the cluster, `client-certificate-data` and `client-key-data` for the user. Thus no `exec`, `auth-provider`, token, `proxy-url` or `insecure-skip-tls-verify`. |
| Each seed namespace exists. | The seed namespace of each consumer in the seed map is in the cluster. |

The three tasks build the same environment:

| Item | Value |
| --- | --- |
| Environment | Minimal, with `env -i`: `PATH` (the folder of `terraform`, `/usr/bin` and `/bin`), `HOME` (a new, empty folder in the temporary folder), `SOPS_AGE_KEY_FILE` (the one key file, refer to [Key location](#key-location)), `TF_INPUT=0` and `CHECKPOINT_DISABLE=1`. No other variable of the shell. Standard input of Terraform from `/dev/null`. The task reads the confirmation from the terminal, not Terraform. |
| `TF_CLI_CONFIG_FILE` | `.mise/tasks/secrets/empty.tfrc`, an empty file. No `provider_installation` and no `dev_overrides`. The task stops if the file is not empty. |
| `TF_DATA_DIR` | A new folder, with `terraform init -lockfile=readonly`. |
| Kubeconfig | A temporary file from `kind get kubeconfig --name <cluster>`, given with `-var=kubeconfig_path=<file>` on the plan command. |

Without a key, `terraform plan` stops at the ephemeral resource before any write, with `Error getting data key: 0 successful groups required, got 0`.

## ESO component

`gitops/infrastructure/external-secrets/` installs ESO from the chart `external-secrets` 2.14.0 of `https://charts.external-secrets.io`. The Helm release is `external-secrets`, in the namespace `external-secrets`. Its CRDs have sync wave `-1`.

The chart names the controller ServiceAccount after its full name. The release name contains the chart name, so the full name is the release name alone: the ServiceAccount is `external-secrets/external-secrets` (`_helpers.tpl` of chart 2.14.0, `external-secrets.fullname`).

The values hold the consumer list and the tenant list. The component renders:

- for each consumer: the seed namespace `secret-seeds-<consumer>`, and a `Role` and a `RoleBinding` in it;
- for each tenant: the seed namespace `secret-seeds-oc-<tenant>`, its ServiceAccount `eso-seed-reader`, its RBAC and the store `oc-<tenant>`;
- the SC9a `ValidatingAdmissionPolicy` and its binding.

### Chart values

| Value | Setting | Effect |
| --- | --- | --- |
| `processPushSecret`, `processClusterPushSecret`, `processClusterExternalSecret` | `false` | ESO cannot copy a Secret out of the cluster. |
| `crds.createPushSecret`, `crds.createClusterPushSecret`, `crds.createClusterExternalSecret` | `false` | The chart does not install these CRDs, so nobody can make these kinds. Each one needs the matching `process*: false`. |
| `processClusterGenerator`, `crds.createClusterGenerator` | `false` | No `ClusterGenerator` CRD and no RBAC rule for it. |
| `processClusterStore` | `true` | For the `oc-*` stores only. |
| `rbac.serviceAccountTokenCreate` | `false` | The controller has no cluster-wide right to make tokens. |
| `rbac.aggregateToEdit`, `rbac.aggregateToView`, `rbac.aggregateToAdmin` | `false` | Only Argo CD makes ESO objects. |

The component has no network policy.

### Seed namespaces

| Item | Value |
| --- | --- |
| Name | `secret-seeds-<consumer>`, or `secret-seeds-oc-<tenant>` |
| Pods | None |
| Pod Security | `restricted` |
| Tenant label | `platform` |
| K15 | `policy/data/labels.yaml` permits `external-secrets` to own the namespaces that match `^secret-seeds-`. `secret-seeds-*` is in `reserved_namespaces`. |

## Namespaced stores

Each consumer component renders these objects in its own namespace, from `sources/templates/secret-store.yaml`. This file is a copy of the shared store template, `gitops/infrastructure/external-secrets/sources/files/secret-store.yaml`. A local chart dependency is not permitted, so each consumer has its own copy, and SC9 checks it.

| Object | Value |
| --- | --- |
| ServiceAccount | `eso-seed-reader` |
| `SecretStore` | `secrets` |
| `Role` | `eso-token-eso-seed-reader`: `create` on `serviceaccounts/token` in the `""` group, with `resourceNames: [eso-seed-reader]` |
| `RoleBinding` | `eso-token-eso-seed-reader`, to the ESO controller ServiceAccount `external-secrets/external-secrets` |
| `ExternalSecret` | One or more, on the store `secrets` |

No component writes into a namespace that another component makes.

### Store `secrets`

| Field | Value |
| --- | --- |
| `provider` | `kubernetes` |
| `remoteNamespace` | `secret-seeds-<consumer>`, set explicitly. The default is `default`. |
| `server.caProvider` | `{type: ConfigMap, name: kube-root-ca.crt, key: ca.crt}`. `server.url` is not set, so it is `kubernetes.default`. |
| `auth.serviceAccount` | `eso-seed-reader` in the consumer namespace |

The `RoleBinding` in `secret-seeds-<consumer>` gives `<consumer>/eso-seed-reader` `get`, `list` and `watch` on `secrets`, and `create` on `selfsubjectrulesreviews`. A binding to a ServiceAccount that does not exist is valid.

Without the token `Role` and `RoleBinding`, the store is `InvalidProviderConfig`, with `cannot create resource "serviceaccounts/token" in the namespace "<consumer>"`.

### `ExternalSecret`

| Field | Value |
| --- | --- |
| `secretStoreRef` | `SecretStore` `secrets` |
| `data[].remoteRef.key` | The name of the seed |
| `data[].remoteRef.property` | `value`. Without it, the value is the JSON of all the pairs of the seed. |
| `dataFrom.find` | Not permitted |
| `target.deletionPolicy` | `Retain`, the default |

The `target.template` of an `ExternalSecret` never copies `argocd.argoproj.io/*` labels or annotations.

When its seed goes away, the consumer Secret keeps its last value, and the `ExternalSecret` shows `SecretSyncedError`. When the `ExternalSecret` goes away, Kubernetes deletes the consumer Secret through its owner reference, also with `Retain`.

To copy a new seed value before the refresh interval, set a new value on the `force-sync` annotation of the `ExternalSecret`:

```bash
kubectl -n <consumer> annotate externalsecret <name> force-sync=$(date +%s) --overwrite
```

The prefixed `external-secrets.io/force-sync` annotation is for `ClusterExternalSecret`.

### Argo CD tracking

| Item | Value |
| --- | --- |
| Tracking method | `annotation`, the default: `application.resourceTrackingMethod` in `argocd-cm`. K9 warns when it is not `annotation`. `annotation+label` is not used. |
| Metadata of a consumer Secret | The `reconcile.external-secrets.io/*` metadata of ESO, the metadata of the template, and an owner reference to the `ExternalSecret`. No `argocd.argoproj.io/tracking-id` and no `argocd.argoproj.io/instance`. |
| Sync status | The consumer Secret is not in `status.resources` of the Application. The Application stays `Synced` and `Healthy` after ESO makes the Secret. |
| Prune | A sync with prune does not delete the consumer Secret. |

## OpenChoreo tenant stores

Each OpenChoreo tenant has one `ClusterSecretStore`. OpenChoreo 1.3.3 refers to a `ClusterSecretStore` by name only, and it makes the `dp-*` cell namespaces at run time.

| Field | Value |
| --- | --- |
| `metadata.name` | `oc-<tenant>` |
| `provider.kubernetes.remoteNamespace` | `secret-seeds-oc-<tenant>` |
| `auth.serviceAccount` | `eso-seed-reader` in `secret-seeds-oc-<tenant>`, with the namespace set explicitly |
| `spec.conditions` | Exactly one: `namespaceRegexes: ["^dp-<tenant>-"]` |
| Token `Role` | In `secret-seeds-oc-<tenant>`: `create` on `serviceaccounts/token`, with `resourceNames: [eso-seed-reader]`. A `RoleBinding` binds it to the ESO controller ServiceAccount. |

- A tenant is its OpenChoreo namespace. Its name is a DNS label with no `-`.
- No other `ClusterSecretStore` exists, and no `ClusterExternalSecret`.
- A second tenant needs the repository role of the OpenChoreo cluster agent: no `clustersecretstores` and no RBAC kinds.

## Consumers

| Consumer | Store | Secrets |
| --- | --- | --- |
| `thunder` | `SecretStore` `secrets` | ThunderID and OAuth client secrets |
| `openchoreo-control-plane` | `SecretStore` `secrets` | Backstage and OAuth client secrets |
| `cert-manager` | `SecretStore` `secrets` | The Cloudflare token, only on an instance that uses DNS-01 |
| Tenant `sandbox` | `ClusterSecretStore` `oc-sandbox`, seeds in `secret-seeds-oc-sandbox` | A test seed |

These namespaces are not consumers:

| Namespace | Reason |
| --- | --- |
| `kagent` | No store and no seed. The kagent controller can write in `kagent`. The `ModelConfig` uses `apiKeyPassthrough: true` and refers to no key Secret. |
| `agentgateway-system` | No store. The proxy gets its Google identity through Workload Identity Federation, with no key. |

A pull request adds a consumer to the consumer list only together with the component of that consumer.

## Trusted platform components

`policy/data/secrets.yaml` lists each component that can read Secrets in all namespaces, with its chart version and its instance. SC16 refuses each other cluster-wide Secret reader.

| Component | Access | Narrowing |
| --- | --- | --- |
| ESO controller | All verbs on `secrets`, in all namespaces | None. `scopedRBAC` turns off the `oc-*` cluster stores. |
| agentgateway controller (v1.7.0) | Reads Secrets in all namespaces. Its deployer can run a pod as the proxy ServiceAccount. | `rbac.gatewayNamespaces` limits the writes only. |
| OpenChoreo cluster agent | `*` on `secrets`, `clustersecretstores` and the RBAC kinds, with the upstream role | The repository role of the agent |
| OpenChoreo controller manager, `openchoreo-api`, cluster gateway (1.3.3) | `get` and `list` on `secrets` in all namespaces. The controller manager also has `watch`. | Where the charts permit it |
| kagent controller (0.10.4) | Reads all the core resources | `rbac.namespaces: [kagent]`. The row applies only to a cluster-wide controller. |
| Argo CD application controller and `argocd-server` (chart 10.11.6) | The default cluster-wide roles. `argocd-server` has `get`, `patch` and `delete` on all resources. | Where the chart permits it |
| cert-manager controller | Reads and writes the certificate Secrets in the namespaces that it serves | Where the chart permits it |

The OpenChoreo API is the service for the tenants, and it can read each seed.

## Checks

| ID | Check | Tool | Rule | Level |
| --- | --- | --- | --- | --- |
| SC0 | Push protection | GitHub | Refuses a push that matches a turned-on pattern. The non-provider patterns are on. | Server |
| SC1 | Secret scan in CI | `lint:secrets` | gitleaks on the commits of the pull request. `lint.yml` installs gitleaks and fetches the full history of the branch. | Fail |
| SC1a | Full history | `gitleaks git` | One scan of the full history. A hit means a rotation. | Once |
| SC2 | Pre-commit | `gitleaks`, `detect-private-key` | Refuses a secret in a commit. | Fail |
| SC3 | age private key | `.gitleaks.toml` | Refuses `AGE-SECRET-KEY-1` and `keys.txt`. | Fail |
| SC4 | SOPS file encrypted | `lint:secrets` | `sops filestatus` gives `{"encrypted":true}` for each `*.sops.yaml`. | Fail |
| SC5 | SOPS recipients | `lint:secrets` | The recipients of each file are equal to its `.sops.yaml` rule. | Fail |
| SC6 | `.sops.yaml` shape | Conftest `sops` | Anchored `path_regex`, the recovery key in each rule, no rule without `path_regex`. | Fail |
| SC7 | No Secret data in `gitops/` | Conftest `kubernetes` | No `data` or `stringData`, also when encrypted. One exception. Refer to [SC7 exception](#sc7-exception). | Fail |
| SC8 | No Sealed Secrets in `gitops/` | Conftest `kubernetes` | No `kind: SealedSecret`. | Fail |
| SC9 | ESO objects | Conftest `kubernetes` | Refer to [SC9 rules](#sc9-rules). | Fail |
| SC9a | `ClusterSecretStore` in the cluster | `ValidatingAdmissionPolicy` | Name `oc-<tenant>`. `remoteNamespace` and the ServiceAccount namespace are `secret-seeds-` plus the name. Exactly the one regex condition. | Deny |
| SC10 | Terraform secrets | Conftest `terraform` | No `data "sops_file"`. No values in `data` or `binary_data` of `kubernetes_secret_v1`. Each `data_wo` has a `data_wo_revision`. | Fail |
| SC11 | Secret resources in a local state | Conftest `terraform` | No resource of the list, for example `google_service_account_key`, in an instance with a local state. It covers each secrets root module through the `instance.yaml` of its parent. | Fail |
| SC12 | Secret variables | Conftest `terraform` | A variable with `sensitive = true` also has `ephemeral = true`. | Fail |
| SC13 | No CI secrets | Conftest `actions` | No `secrets.<name>` except `GITHUB_TOKEN`, no `secrets: inherit`, no `toJSON(secrets)`. | Fail |
| SC14 | Required check | Ruleset on `main` | The ruleset requires `Run every linter and check`. | Server |
| SC15 | Path of the decrypted values | Conftest `terraform --combine` | Refer to [SC15 rules](#sc15-rules). | Fail |
| SC16 | RBAC of Secrets and workloads | Conftest `kubernetes` on `gitops/**/rendered/` | Refer to [SC16 rules](#sc16-rules). | Fail |

Each Conftest rule has a test that passes and a test that fails. The legacy `kubernetes/` tree keeps its own rule: a `Secret` has no values, or SOPS encrypts it.

### SC7 exception

| Field | Value |
| --- | --- |
| Path | `gitops/clusters/kind-local/rendered/kagent/` |
| Secret | `kagent-postgresql` |
| Key | `POSTGRES_PASSWORD`, the only key |
| Value | Exactly `a2FnZW50`, the base64 of the chart constant `kagent` |

`policy/data/secrets.yaml` lists the exception with its path. No other exception exists.

### SC9 rules

- An `ExternalSecret` refers to the `SecretStore` `secrets`, or to the `ClusterSecretStore` `oc-<tenant>` from a cell of that tenant.
- Each `remoteRef` has `property: value`. No `dataFrom.find`.
- A `SecretStore` sets `remoteNamespace` to the seed namespace of its own namespace.
- A `ClusterSecretStore` has the name `oc-<tenant>`. Its `remoteNamespace` and `auth.serviceAccount.namespace` are `secret-seeds-oc-<tenant>`. It has exactly one condition, `namespaceRegexes: ["^dp-<tenant>-"]`.
- No `ClusterExternalSecret`, `PushSecret` or `ClusterPushSecret`.
- A `RoleBinding` in `secret-seeds-<consumer>` binds only the store ServiceAccount of `<consumer>`.
- Each consumer of the list has, in its own component, a store `secrets`, a ServiceAccount `eso-seed-reader`, and the token `Role` and `RoleBinding`. Each store has a consumer in the list.
- The token `Role` has only `create` on `serviceaccounts/token`, with `resourceNames: [eso-seed-reader]`. Its `RoleBinding` binds only the ESO controller ServiceAccount.

### SC15 rules

- Only `instances/<instance>/secrets/main.tf` refers to `ephemeral.sops_file`, and only as an input of `module.secret_seeds`.
- No `local` refers to `ephemeral.*`.
- No `provisioner` and no `action` block in the secrets root module, or in a module with an ephemeral variable.
- In a module with an ephemeral variable, the variable goes only into a write-only argument of the list. The module has no `provider` block and no `ephemeral` block.
- `module.secret_seeds` has no `providers` argument.
- `bootstrap-secret-seeds` uses only `hashicorp/kubernetes`.
- The `provider "kubernetes"` of the secrets root module has only `config_path`, set to the file that the task makes.

### SC16 rules

SC16 reads each `Role`, `ClusterRole`, `RoleBinding` and `ClusterRoleBinding`, also the bindings to the built-in roles `cluster-admin`, `admin` and `edit`. A rule matches `secrets` also through `resources: ["*"]` or `apiGroups: ["*"]`.

- Only a trusted platform component, at its chart version and on its instance, can read Secrets in all namespaces.
- No role of the kagent tool server has `*`, `secrets` or `nonResourceURLs`.
- SC16 permits the kagent getter and writer `Role` objects with `""/*` only in `kagent`, by name.
- Outside the allowlist, no ServiceAccount gets these rights in a protected namespace: `create`, `update` or `patch` on pods or workload kinds, `create` on `serviceaccounts/token`, `pods/exec`, the RBAC kinds, `impersonate`.

The workload kinds are `deployments`, `statefulsets`, `daemonsets`, `replicasets`, `jobs` and `cronjobs`.

A protected namespace holds a seed, a consumer Secret, or a ServiceAccount with a federated Google identity, for example `agentgateway-system`. `policy/data/secrets.yaml` lists the protected namespaces and the allowlist:

| Namespace | Allowlist |
| --- | --- |
| `agentgateway-system` | The deployer `RoleBinding` of the agentgateway controller, and the Argo CD roles |
| Each consumer namespace, and each `secret-seeds-oc-<tenant>` | The token `Role` `eso-token-eso-seed-reader` and its `RoleBinding` to the ESO controller ServiceAccount |

A token `Role` without `resourceNames`, with other verbs, or bound to another subject fails.

## Agent rules

Agents run as the same OS user as the person who applies the secrets. These rules are rules, not controls.

| Rule | Detail |
| --- | --- |
| Agents never run a `secrets:*` task. | The terminal check of `secrets:apply` and `secrets:destroy` stops only a run with no terminal. Also never `sops decrypt`, `sops edit`, `sops exec-env`, `kubectl get secret -o yaml`, or a `terraform` command in `instances/*/secrets/`. |
| Agents never read or delete a key or a state. | `keys.txt` and each `.tfstate` file. |
| Agents never apply account changes. | No `terraform` command in `accounts/`, no provider tokens. |
| Agents never merge. | Also not a pull request that changes `accounts/`. |
| Agents never use the proxy identity of agentgateway. | No `kubectl create token` for the proxy ServiceAccount of `agentgateway-system`, no read of its token file, no hand edit of `accounts/gcp/jwks/`. Agents can run `vertex:jwks`. |
| Agents can run `instance:up` and `instance:down`. | After a re-create of a cluster with seeds, the agent tells the person who applies the secrets. |
| No agent session runs during a SOPS edit or a `secrets:apply`. | `secrets:edit`, `secrets:plan`, `secrets:apply`, `secrets:destroy` and `secrets:rotate` run only with no agent session. |
| Agents write the code around a secret, never the value. | A value in the output of an agent gets a rotation. |

### What agents can read

| Item | Agents can read it | Control |
| --- | --- | --- |
| SOPS files, `.sops.yaml`, public keys | Yes | They are public. |
| The scope key `keys.txt` | Yes | It opens only test values. A hardware key protects production values. |
| The recovery key | No | It is offline. |
| States and plans | Yes | They hold no value: the Terraform rules and the state test. |
| The kind kubeconfig and the Secrets of `kind-local` | Yes | A test cluster with test values. It can also mint a token for the agentgateway proxy. |
| The plaintext during `sops edit` | Yes, also the swap, backup and undo files of the editor | No agent session. An editor without these files. |
| The plaintext during `secrets:apply` | Yes, if agent code or a changed file sends it out | Only a person applies, after a review. SC15. The clean environment. |
| CI logs | Yes | No secret in CI (SC13). |

## Related pages

- [Policies](policies.md): the other Conftest policies.
- [Mise tasks](mise-tasks.md): the other tasks.
- [Labels and annotations](labels-and-annotations.md#checks): K15 and the tenant label.
- [Apply the secrets](../how-to/apply-the-secrets.md)
- [Add a secret](../how-to/add-a-secret.md)
- [Rotate a secret](../how-to/rotate-a-secret.md)
- [Add a secret consumer](../how-to/add-a-secret-consumer.md)
- [Secrets management](../explanation/secrets-management.md)
