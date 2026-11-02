---
rfc: "0006"
status: draft
start-date: 2026-11-02
pr: 178
---

# RFC 0006: Secrets management

## Summary

This RFC tells where each secret of the repository lives, how it gets to its consumer, and which checks stop a plaintext secret in Git. The owner selected SOPS and the External Secrets Operator (ESO) on 2026-10-30. This RFC gives the design for that decision. SOPS with age encrypts the secret files in Git. Only the owner decrypts them, in a separate "secrets root module" with its own state, that only the owner applies. Terraform uses ephemeral resources and write-only arguments, so that no secret goes into the state. It writes the secrets of each consumer into a seed namespace for that consumer only. ESO copies them into the namespace of the consumer, through a namespaced store with the stable name `secrets`. OpenChoreo needs cluster stores; the RFC proposes one store for each tenant (question 7). The RFC compares the ESO backends, gives the SOPS key management, and gives the full path of the Google Gemini API key to kagent for milestone M1. It gives requirements on the RBAC of kagent for RFC 0008, the checks for pre-commit, CI and Conftest, and the rollout. Last, it tells which gap the agents make, because they run as the owner.

## Motivation

### Decisions so far

- **2026-10-30 (owner, in chat):** secrets use SOPS and ESO. The repository drops Sealed Secrets. The legacy tree `kubernetes/` on `olympus`, the production Raspberry Pi, keeps Sealed Secrets until the migration of the Pi.
- **2026-11-02 (owner, in chat):** milestone M1 installs kagent and agentgateway on `kind-local`, with Google Gemini as the model provider.
- **[RFC 0002](0002-how-we-work.md)** gives the four controls that enforce a rule: rulesets, Git hooks, CI checks and Conftest policies. Its review policy (ADR 0010 in PR #177) makes the owner the reviewer of a module and of CI.
- **[RFC 0003](0003-repository-structure.md)** gives the tree. It does not commit `*.tfvars`, and it says: "The secrets RFC tells where the values come from." It removes `CODEOWNERS` (ADR 0022 in PR #177). Thus this RFC uses no `CODEOWNERS` rule.
- **[RFC 0005](0005-repository-scope-and-naming.md)**: until a remote backend exists, a root module with local state does not hold a resource with a secret. For now, the agents get no provider token, and the owner runs `plan` and `apply`.

### Current state

The author read `origin/main` at `d7b24a8` on 2026-11-02.

- No secret of the new tree exists yet. `gitops/clusters/kind-local/cluster.yaml` holds only `argocd`. `kind-local` runs Kubernetes 1.36.1 (`modules/cluster-kind`).
- `policy/kubernetes/kubernetes.rego` refuses a `Secret` with values in `data` or `stringData`, except when SOPS encrypted it. `policy/terraform/terraform.rego` has only the provider rules: the RFC 0005 policy against secret resources in local state is not on `main` yet.
- `.pre-commit-config.yaml` runs `gitleaks` 8.30.1 and `detect-private-key`. `mise run lint` and `lint.yml` do not run gitleaks, and `lint.yml` checks out one commit.
- GitHub secret scanning and push protection are on. The non-provider patterns are off (`gh api repos/gsuquet/homelab`, 2026-11-02). A ruleset on `main` requires the status `Run every linter and check` (`AGENTS.md`).
- `bootstrap-cert-manager` writes a Cloudflare API token into `kubernetes_secret_v1.data`. Terraform then keeps the token in plain text in the state ([HashiCorp: manage sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)).
- `modules/cluster-kind` has no `EncryptionConfiguration`, so the Secrets on `kind-local` are not encrypted at rest.
- `mise run instance:up` runs a full `terraform apply -input=false`. Agents bring `kind-local` up to test their changes, with the local state that the owner also uses.
- `docs/explanation/secret-management.md` and `docs/how-to/manage-secrets.md` teach Sealed Secrets.

### Problems

1. **No home for a secret value.** The only rule is "no plaintext in Git".
2. **The Terraform state holds secrets in plain text.** A plain `kubernetes_secret_v1` or a `data "sops_file"` writes the value into the state.
3. **The chicken and the egg.** ESO needs a credential to read its backend, and SOPS needs a private key. Neither can be in Git.
4. **The agents share the machine of the owner, and they write the code that runs with the secrets.**
5. **M1 needs a Gemini key on `kind-local` now.**

### Use cases

- **U1. The Gemini key for M1.** kagent on `kind-local` reads a Gemini key. The key is not in Git in plain text, not in the state, and not in CI logs.
- **U2. A new secret for a component**, for example a DNS-01 token of cert-manager. The kagent namespace must not get that token.
- **U3. A rotation** of the Gemini key, without a change in the code of the component.
- **U4. A lost laptop.** The owner decrypts the files from a different machine.
- **U5. A cloud instance later** gets its secrets from Google Cloud Secret Manager, with no change to the `ExternalSecret` objects.
- **U6. An agent writes the code.** It does not see the value, cannot commit it, and its code cannot send it out during the apply of the owner.
- **U7. An agent tests `kind-local`** without the age key, and without the secrets of the owner going away.

## Proposal

### Concepts

- **Secret value.** A value that gives access: an API key, a token, a private key. A public key or an account ID is not a secret value.
- **SOPS file.** `instances/<instance>/secrets/secrets.sops.yaml`. SOPS encrypts each value, and keeps the keys of the map in plain text.
- **Scope key.** An age key for one SOPS file. Its private key is on the machine of the owner only.
- **Recovery key.** An age key that the owner creates on a machine that no agent uses, or on an offline live system, and keeps offline. Each SOPS file has it as a second recipient.
- **Secrets root module.** `instances/<instance>/secrets/`: a small Terraform root module with its own local state. It reads the SOPS file and writes the seeds. Only the owner applies it, with `mise run secrets:apply <instance>`. The instance root module never reads the SOPS file.
- **Seed namespace.** `secret-seeds-<consumer>`, one for each consumer. It holds only the secrets of that consumer. No pod runs in it.
- **Consumer store.** A namespaced `SecretStore` with the fixed name `secrets` in the namespace of each consumer. It reads only the seed namespace of that consumer.
- **ExternalSecret.** The ESO object in the namespace of a consumer. It holds no secret, so it goes into Git with the component.

### The flow of a secret

In text: the owner writes the value into the SOPS file. Git holds only the ciphertext. The owner runs `secrets:apply`: the secrets root module decrypts the file in memory with an ephemeral resource. It writes each value into the seed namespace of its consumer through a write-only argument, so the state does not hold it. Argo CD syncs ESO, the seed namespaces, the consumer stores and the `ExternalSecret` objects. ESO copies each value into the Secret of the consumer.

```mermaid
flowchart LR
    subgraph owner["Machine of the owner"]
        V[Secret value] -->|sops edit| F["instances/kind-local/secrets/secrets.sops.yaml"]
        K[(age scope key)]
    end
    F -->|git push: ciphertext only| G[(GitHub, public)]
    subgraph tf["secrets:apply, owner only, own state"]
        E["ephemeral sops_file"]
        W["kubernetes_secret_v1 data_wo"]
        E -->|value in memory| W
    end
    F --> E
    K --> E
    subgraph cluster["kind-local"]
        S["Secret in secret-seeds-kagent"]
        SS["SecretStore secrets in kagent"]
        ES["ExternalSecret in kagent"]
        T["Secret kagent-gemini"]
        MC["ModelConfig"]
    end
    W -->|one time per change| S
    G -->|Argo CD sync: no secret| SS
    G -->|Argo CD sync: no secret| ES
    SS -->|reads only its seed namespace| S
    ES -->|ESO writes| T
    MC -->|apiKeySecret| T
```

### What changes for an author

- To add a secret value, ask the owner. They run `mise run secrets:edit <instance>`. An agent never writes or reads a value.
- Add the key to the seed map of the secrets root module, under its consumer.
- Add the consumer to the consumer list of the `external-secrets` component, and add an `ExternalSecret` that refers to the store `secrets` in its own namespace.
- Never put a `kind: Secret` with data into `gitops/`. Never use `data "sops_file"`. A check refuses both.
- Never apply `instances/<instance>/secrets/`. Only the owner does it. `mise run instance:up` stays free for agents.

## Detailed design

### Scope

| Class | Where the value lives | How it gets to its consumer | In scope |
| --- | --- | --- | --- |
| Kubernetes secrets | The SOPS file of the instance | Secrets root module to a seed namespace, then ESO | Yes |
| Terraform inputs, for example the token of `bootstrap-cert-manager` | The same SOPS file | `ephemeral "sops_file"` to a write-only argument | Yes |
| Provider credentials | Not in the repository, for now | Environment variables in one apply session (RFC 0005) | Yes: the RFC 0005 rule stays. Refer to question 4. |
| Bootstrap secrets | age keys: machine of the owner and offline. ESO: no credential on `kind-local`. | Refer to "Bootstrap" | Yes |
| CI secrets | None | None | Yes: the rule is "none" |
| Sealed Secrets on `olympus` | The Sealed Secrets controller | Unchanged | No |

**Out of scope: Sealed Secrets on `olympus`.** They go away in the migration of the Raspberry Pi to Talos, when `instances/olympus/` and `gitops/clusters/olympus/` come. Then each `SealedSecret` becomes a key in the SOPS file of `olympus` and an `ExternalSecret`. The key backup of RFC 0005 (step R0h) stays until then. The migration must also turn on the encryption of Secrets at rest on `olympus`. A SOPS file for `olympus` can go on the allowlist of the RFC 0003 legacy check.

### SOPS key management

#### age or a cloud KMS

| Criterion | age | GCP Cloud KMS |
| --- | --- | --- |
| Cost | Free | A software key version costs about USD 0.06 a month, and USD 0.03 for each 10,000 operations ([Cloud KMS pricing](https://cloud.google.com/kms/pricing)) |
| Offline use | Yes | No |
| Agent access | Each process of the owner can read the key file | Only during a sign-in session of the owner |
| Dependencies | `sops`, `age` | A GCP project with a billing account |

Recommendation: **age** for all scopes now. SOPS recommends it over PGP ([SOPS: age](https://github.com/getsops/docs/blob/main/content/en/docs/usage/identities/age/_index.md)). It works offline and costs nothing. A cloud KMS is better against the agents only while the owner signs out. Refer to question 3 for the place of the private key.

#### Keys and recipients

- **One scope key for each SOPS file**, first `kind-local`. A leaked scope key opens only its file.
- **One recovery key**, created on a machine that no agent uses or on an offline live system, and kept offline, for example printed. A delete of a key file on the machine of the owner is not enough: the disk keeps the data, and an agent can read the file before the delete.
- **No SSH recipients.** Without another key, SOPS reads `~/.ssh/id_ed25519` and `~/.ssh/id_rsa` to decrypt ([SOPS: age](https://github.com/getsops/docs/blob/main/content/en/docs/usage/identities/age/_index.md)). Those keys also sign and push.
- **No PGP.**

SOPS reads the scope key from `keys.txt` in `$XDG_CONFIG_HOME/sops/age/`, or on macOS in `$HOME/Library/Application Support/sops/age/`. `SOPS_AGE_KEY_FILE`, `SOPS_AGE_KEY` and `SOPS_AGE_KEY_CMD` change this. SOPS supports age plugins and age identities with a passphrase ([SOPS changelog](https://github.com/getsops/sops/blob/main/CHANGELOG.md)).

#### `.sops.yaml`

`.sops.yaml` at the root has one creation rule for each SOPS file. SOPS uses the first rule that matches. It looks for `.sops.yaml` from the working folder ([SOPS: configuration file](https://github.com/getsops/docs/blob/main/content/en/docs/usage/identities/config-file/_index.md)), so the mise tasks run `sops` from the root. The rules:

- Each `path_regex` starts with `^` and ends with `$`, and matches one file, for example `^instances/kind-local/secrets/secrets\.sops\.yaml$`.
- Each rule has the scope key and the recovery key.
- No rule without a `path_regex`.

The tooling PR pins `sops` (latest release on 2026-11-02: `v3.13.3`, [SOPS releases](https://github.com/getsops/sops/releases)) and `age` in `.mise/config.toml`.

#### The edit of a SOPS file

`sops edit` writes the plaintext into a temporary file and opens an editor as the user of the owner. Each process of that user can read that file, and editor swap, backup and undo files can keep the plaintext. Thus no agent session runs during `mise run secrets:edit`, and the task sets an editor with swap, backup and undo files off.

#### Rotation, recovery and backup

| Event | Steps |
| --- | --- |
| A new recipient | Add the public key to the rule, then `sops updatekeys <file>`. |
| A recipient leaks or goes away | Remove it from the rule, `sops updatekeys <file>`, then `sops rotate --in-place <file>`, in this order. Then rotate each value at its issuer. |
| Planned data key rotation | `sops rotate --in-place <file>` once a year. |
| A value changes | `mise run secrets:edit <instance>`, then `mise run secrets:apply <instance>`. |

Source: [SOPS: key management](https://github.com/getsops/docs/blob/main/content/en/docs/usage/key-management/_index.md). The cluster never holds an age key, so an age key rotation needs no change in a cluster.

The recovery key decrypts each file. The owner tests it each year on the offline system. After a loss of a scope key, the owner decrypts with the recovery key, makes a new scope key, and runs the "recipient leaks" steps. Git keeps the SOPS files. If both keys are lost, the owner creates each value again at its issuer.

### Terraform secrets

Rules for all Terraform code:

1. **No secret in Terraform, if possible.** A secret that only a cluster uses goes through a seed namespace and ESO.
2. **Ephemeral input.** Read a SOPS file only with the `carlpett/sops` ephemeral resource `sops_file` (version 1.4.1, [registry](https://registry.terraform.io/providers/carlpett/sops/1.4.1/docs)). Terraform does not store ephemeral resources in state or plan files ([HashiCorp: manage sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)).
3. **Write-only output.** The value goes only into a write-only argument, for example `data_wo` of `kubernetes_secret_v1`, which provider 3.1.0 has ([registry](https://registry.terraform.io/providers/hashicorp/kubernetes/3.1.0/docs/resources/secret_v1)). Write-only arguments need Terraform 1.11; the repository uses 1.17.0.
4. **No `data "sops_file"`.** Its result goes into the state. The provider documentation warns: "To prevent plaintext secrets from being written to disk, you *must* use a secure remote state backend."
5. **Ephemeral variables.** A secret variable has `sensitive = true` and `ephemeral = true`.
6. **No resource that makes a secret, in local state** (RFC 0005). This RFC adds `google_apikeys_key`, because its `key_string` is the key ([registry](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/apikeys_key)). The owner creates the Gemini key in the console.
7. **A fixed path for the decrypted values.** Refer to the next section.

`data_wo_revision` must change to push a new value, because Terraform does not see a write-only value. The revision comes from the hash of the encrypted file, which changes after each `sops edit`.

`bootstrap-cert-manager` changes from `data` to `data_wo`, with `cloudflare_api_token` as an ephemeral variable.

#### The path of the decrypted values

Terraform permits an ephemeral value only in a write-only argument, another `ephemeral` block, `locals`, an ephemeral variable or output, a `provider` block and a provisioner. "Otherwise, Terraform throws an error when it plans your changes" ([HashiCorp: ephemeral block](https://developer.hashicorp.com/terraform/language/block/ephemeral)). Thus Terraform already refuses routes through `local_file`, `terraform_data` or a data source. These routes stay, and agents write the code:

- A provisioner, or a `local` that hides the reference.
- A changed `provider "kubernetes"` (`host`, `exec`, `proxy_url`), or a `providers` argument on `module.secret_seeds`. The seeds then go to a different host through a legal `data_wo`.
- A module with an ephemeral variable that feeds the write-only argument or the `ephemeral` block of another provider.
- `action` blocks (Terraform 1.14 and later).
- Files outside HCL that run during the apply: `.mise/tasks/`, the mise `[env]` and hooks, `.terraform.lock.hcl`, and the Terraform CLI configuration.

The controls:

- **SC15 (Conftest, with `--combine`).** Only `instances/<instance>/secrets/main.tf` refers to `ephemeral.sops_file`, and only as an input of `module.secret_seeds` or of a write-only argument on the list in `policy/data/secrets.yaml`. No `local` refers to `ephemeral.*`. No `provisioner` and no `action` block in the secrets root module or in a module with an ephemeral variable. In such a module, an ephemeral variable goes only into a listed write-only argument, and the module has no `provider` block and no `ephemeral` block. `module.secret_seeds` has no `providers` argument. `bootstrap-secret-seeds` uses only `hashicorp/kubernetes`. The `provider "kubernetes"` block of the secrets root module has only `config_path` and `config_context`.
- **The review of the owner.** Before each `secrets:apply`, the owner reads each diff since their last apply under `instances/`, `modules/`, `.mise/`, the mise configuration and the `.terraform.lock.hcl` files. The provider block and the kubeconfig context are review items: Conftest cannot tell a good host from a bad one.

#### The secrets root module

The secrets of an instance are in `instances/<instance>/secrets/`, a separate root module with its own local state. It holds `terraform.tf`, `providers.tf`, `main.tf` and `secrets.sops.yaml`. Its `kubernetes` provider reads the kubeconfig context of the cluster, for example `kind-kind-local`, after `instance:up` made it.

- **Only the owner applies it**, with `mise run secrets:apply <instance>`, after their review.
- **The instance root module never reads the SOPS file.** Thus an agent, a new clone, or a later agent sandbox without the age key runs `mise run instance:up kind-local` as before. That apply does not touch the seeds, because they are in a different state.
- **The seed namespaces always exist.** The `external-secrets` component creates them from its consumer list, with the RBAC of each store. Thus Argo CD syncs the same objects with and without the seeds. Without the seeds, each `ExternalSecret` waits, and its consumer has no key.
- **A new cluster loses the seeds.** After an agent re-creates `kind-local`, the owner runs `secrets:apply` again.

### Bootstrap

**The SOPS key.** Only the owner has it, on their machine and offline. Terraform decrypts on the machine of the owner. No key goes into a cluster, and Argo CD never decrypts.

**The first ESO credential.** On `kind-local`, each store uses the ESO `kubernetes` provider with a ServiceAccount that the store names. The provider does not accept the ServiceAccount of the operator itself ([ESO: Kubernetes provider](https://external-secrets.io/latest/provider/kubernetes/)). No secret credential exists to bootstrap: Kubernetes RBAC is the control.

A later cloud backend uses GKE Workload Identity or Workload Identity Federation ([ESO: Google Cloud Secret Manager](https://external-secrets.io/latest/provider/google-secrets-manager/)). The federation file "doesn't contain a private key" ([Google Cloud: federation with Kubernetes](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes)). Never a service account key.

```mermaid
sequenceDiagram
    participant O as Owner or agent
    participant TF as Terraform
    participant K as kind-local API
    participant A as Argo CD
    participant E as ESO
    O->>TF: mise run instance:up (no secrets)
    TF->>K: kind, Gateway API, Cilium, Argo CD
    A->>K: sync external-secrets: CRDs, controller, seed namespaces, RBAC
    A->>K: sync kagent: namespace, SecretStore secrets, ExternalSecret
    O->>TF: owner only: mise run secrets:apply
    TF->>K: Secret gemini-api-key in secret-seeds-kagent (data_wo)
    E->>K: read secret-seeds-kagent, write kagent/kagent-gemini
```

In text: the owner or an agent runs `instance:up`. Argo CD syncs ESO with the seed namespaces and their RBAC, then kagent with its store and `ExternalSecret`. Then the owner runs `secrets:apply`, which writes the seeds. ESO copies them to kagent.

### The ESO backend

#### Options

| Option | Cost and free tier | Argo CD fit | Offline and `kind-local` | Blast radius |
| --- | --- | --- | --- | --- |
| **A1. GCP Secret Manager** | Free each month: 6 active versions, 10,000 accesses, 3 rotation notifications, for each billing account. Then about USD 0.06 a month for each version and USD 0.03 for each 10,000 accesses ([pricing](https://cloud.google.com/secret-manager/pricing)). Needs billing. | Good: provider `stable` ([ESO: stability](https://external-secrets.io/latest/introduction/stability-support/)) | No offline. On Kind: federation with a JWKS that changes with each new cluster, or a service account key (refused) | A GCP identity with `roles/secretmanager.secretAccessor` |
| **A2. AWS Secrets Manager, SSM Parameter Store, Azure Key Vault** | SSM standard: no extra charge, 10,000 parameters ([AWS: parameter tiers](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html)). Secrets Manager: paid for each secret ([AWS](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)). Key Vault: refer to the verify list. | Good: `stable` | No offline. On Kind: a static key or federation | The IAM or RBAC of the identity |
| **B1. SOPS in Argo CD: KSOPS or helm-secrets** | Free | Bad. Argo CD "strongly caution[s] against" secret injection at manifest generation, and keeps generated manifests "in plaintext in its Redis cache" ([Argo CD: secret management](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)). Here `rendered/` goes into Git. | Yes | The age key in the repo server |
| **B2. ESO webhook to a SOPS service** | Free | Medium: webhook provider `alpha` | Yes | The age key in the cluster |
| **C. Seed namespaces with the ESO `kubernetes` provider (recommended)** | Free | Good: Argo CD syncs only objects with no secret. Provider `beta`. | Yes, offline | One consumer for each store. The ESO controller and cluster administrators read all. |
| **D. Vault or OpenBao** | Free software, new stateful service | Good | Yes | A new unseal key and backups |
| **E. Bitwarden, Infisical, 1Password** | Refer to the verify list | Medium: providers `alpha` | No offline | A machine token, a new vendor |
| **F. No ESO: Terraform writes each consumer Secret** | Free | Medium | Yes | Smaller, but against the decision of 2026-10-30 |

Recommendation: **C on `kind-local`, and on `olympus` after its migration.** It is free, offline, and needs no cloud credential and no age key in the cluster. A1 replaces it on a cloud instance (U5). Only the store template of the `external-secrets` component changes; the `ExternalSecret` objects keep `secrets`. The owner decides in question 1.

The free tier of A1 is small: a one-hour refresh makes about 720 accesses a month for each key, so 10,000 accesses cover about 13 keys.

#### One store for each consumer

A store gives each of its users every Secret that it reads. The `kubernetes` provider needs `get`, `list` and `watch` on `secrets` ([ESO: Kubernetes provider](https://external-secrets.io/latest/provider/kubernetes/)), and `list` reads the values ([Kubernetes: good practices for Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)). `resourceNames` cannot reliably limit `list` and `watch`. Thus the rule: **a namespace that can use a store gets every seed that the store reads.**

The design: one seed namespace and one `SecretStore` `secrets` for each consumer. `kagent/secrets` reads only `secret-seeds-kagent`. Each store uses the ServiceAccount `eso-seed-reader` in its own namespace. A `RoleBinding` in `secret-seeds-<consumer>` gives it `get`, `list` and `watch` on `secrets`, and the `create` on `selfsubjectrulesreviews` that the provider needs. A pod that runs as `eso-seed-reader` reads only the seeds of its own consumer.

**Who creates ESO objects: only Argo CD.** `rbac.aggregateToEdit`, `rbac.aggregateToView` and `rbac.aggregateToAdmin` are `false`. Thus `edit` and `admin` subjects in a namespace cannot create a store or an `ExternalSecret`.

**One exception: OpenChoreo (question 7).** OpenChoreo 1.3.3 refers only to a `ClusterSecretStore`, by name, and creates its cell namespaces at run time. Until the owner decides, the body permits the recommended option of question 7: one `ClusterSecretStore` for each OpenChoreo tenant, named `oc-<tenant>`. Each reads only `secret-seeds-oc-<tenant>`, and its `spec.conditions` limit it to the cell namespaces of that tenant, by label. `processClusterStore` stays `true` for these stores. No other `ClusterSecretStore`, and no `ClusterExternalSecret`.

#### The ESO component

`gitops/infrastructure/external-secrets/` installs the upstream chart from `https://charts.external-secrets.io` ([ESO: getting started](https://external-secrets.io/latest/introduction/getting-started/)) with an exact version. Its values hold the consumer list. For each consumer, its templates render the seed namespace (Pod Security `restricted`, RFC 0004 keys), the `ServiceAccount`, the `Role` and `RoleBinding`, and the store. The CRDs get the wave `-1`.

ESO supports only its latest minor version. On 2026-11-02 that is 2.14, which lists Kubernetes 1.37 ([ESO: stability](https://external-secrets.io/latest/introduction/stability-support/)). `kind-local` runs 1.36. The last release that lists 1.36 is 2.13, and its support ended on 2026-10-23. The implementation PR tests 2.14 on 1.36. If the test fails, it pins 2.13 until the Kind node moves to 1.37.

The ESO controller has `get`, `list`, `watch`, `create`, `update`, `patch` and `delete` on `secrets` in all namespaces. Thus ESO can read and write each Secret of the cluster. The chart values, after the ESO security guide ([ESO: security best practices](https://external-secrets.io/latest/guides/security-best-practices/)):

- `processPushSecret`, `processClusterPushSecret` and `processClusterExternalSecret` are `false`. ESO cannot copy a Secret out.
- `rbac.serviceAccountTokenCreate: false`, with a `Role` with `resourceNames` that permits a token only for each `eso-seed-reader`.
- The three `rbac.aggregateTo*` values are `false`.
- A default-deny network policy waits for the zero-trust RFC.

### The Gemini key path for M1

#### Gemini API or Vertex AI

| Criterion | Gemini API (kagent provider `Gemini`) | Vertex AI (kagent provider `GeminiVertexAI`) |
| --- | --- | --- |
| Credential | An API key | A Google Cloud identity, as a credentials JSON in a Secret |
| Billing | Not necessary | Necessary |
| Data use | Free tier: "Your prompts and responses may be used to improve Google products." Paid tier: never. | Never |
| On `kind-local` | One string in a Secret | A service account key (refused), federation, or the login file of the owner (refused) |

Sources: [Google Cloud: migrate from the Gemini API](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/migrate/migrate-google-ai), [kagent: Gemini](https://kagent.dev/docs/kagent/0.x/supported-providers/gemini/), [kagent: Google Vertex AI](https://kagent.dev/docs/kagent/0.x/supported-providers/google-vertexai/). Google permits "authorization keys with Gemini API in production, because Gemini API doesn't create resources in Google Cloud projects" ([Google Cloud: API key best practices](https://docs.cloud.google.com/docs/authentication/api-keys-best-practices)).

Recommendation: **the Gemini API with an API key, for M1.** The owner decides the tier in question 2.

The owner creates the key in the console, in a dedicated GCP project, with an API restriction to the Generative Language API ([Google Cloud: API keys](https://docs.cloud.google.com/docs/authentication/api-keys)). It has no IP address restriction, because a laptop changes networks.

#### End to end

| Step | Who | What |
| --- | --- | --- |
| 1 | Owner | Create the key in the console, with the API restriction. |
| 2 | Owner, no agent session | `mise run secrets:edit kind-local`: add `gemini-api-key`. Commit the ciphertext. |
| 3 | Agent or owner, the owner reviews | Add `gemini-api-key` under `kagent` in the seed map of the secrets root module. |
| 4 | Agent or owner | Add `kagent` to the consumer list of `external-secrets`. |
| 5 | Agent or owner, in the kagent component of RFC 0008 | `ExternalSecret` `kagent-gemini`: store `secrets`, remote key `gemini-api-key`, target Secret `kagent-gemini`, key `GOOGLE_API_KEY`. |
| 6 | Owner only | `mise run secrets:apply kind-local`. |
| 7 | ESO, then kagent | ESO writes `kagent/kagent-gemini`. The `ModelConfig` reads it with `apiKeySecret: kagent-gemini` and `apiKeySecretKey: GOOGLE_API_KEY`. |

The Secret name, the key and the `ModelConfig` fields come from [kagent: Gemini](https://kagent.dev/docs/kagent/0.x/supported-providers/gemini/). `apiKeySecret` "Must be a reference to the name of a secret in the same namespace as the referencing ModelConfig" ([kagent: API reference](https://kagent.dev/docs/kagent/0.x/resources/api-ref)), so the Secret is in `kagent`.

**If agentgateway holds the key** ([kagent: agentgateway](https://kagent.dev/docs/kagent/0.x/supported-providers/byo-agentgateway/)), the consumer is `agentgateway-system`. The target is `google-secret` with the key `Authorization`, which an `AgentgatewayBackend` reads through `policies.auth.secretRef` ([agentgateway: Gemini](https://agentgateway.dev/docs/kubernetes/latest/llm/providers/gemini/)). The SOPS file stays the same.

#### Requirements on kagent for RFC 0008

RFC 0008 owns the kagent values. It must meet these requirements, and this RFC keeps the check SC16:

- Pin the kagent chart to an exact version.
- Never set `providers.*.apiKey`. The chart then renders a Secret with the key into `rendered/`. SC7 refuses it.
- **`kagent-tools`:** `rbac.readOnly: true` and `rbac.allowSecrets: false`. With the default `readOnly: false`, its role permits all verbs on all resources. Then an agent that a prompt injection controls can read each seed namespace, create an `ExternalSecret`, or create a pod that mounts any Secret. No role or binding of the tool server has `*` or `secrets`.
- **The kagent controller.** In chart 0.10.4, its `ClusterRole` has `get`, `list` and `watch` on all resources of the core group, thus each Secret of the cluster, and a second role writes them. The upstream chart fails SC16. Question 8 gives the options. The recommended option limits the controller to `rbac.namespaces: [kagent]`; then it reads only the Secrets of `kagent`, which hold only its own key.
- `controller.auth` lets each person who reaches the UI drive the agents in its default mode. RFC 0008 decides it.

#### Rotation of the Gemini key

1. Create a second key with the same restriction.
2. `secrets:edit` with the new value, commit, `secrets:apply`.
3. ESO updates `kagent-gemini` at the next refresh, or at once with a forced refresh.
4. Restart the pods that read the key, if kagent does not reload it.
5. Check that an agent answers, then delete the old key.

Target period: 90 days, and at once after a suspected leak ([Google Cloud: API key best practices](https://docs.cloud.google.com/docs/authentication/api-keys-best-practices)).

#### Who can read the key

The owner (cluster administrator), the ESO controller, `kagent/eso-seed-reader`, the kagent controller and agent pods, each subject that can create a pod in `kagent`, and Argo CD with its default cluster-wide role. "A user who can create a Pod that uses a Secret can also see the value of that Secret" ([Kubernetes: good practices for Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)). No other person or tool gets `list` or `watch` on Secrets.

### CI secrets

**No repository secret, no environment secret, and no long-lived cloud key in GitHub Actions.** The workflows need only `GITHUB_TOKEN` with `contents: read`. A later cloud job uses GitHub OIDC with Workload Identity Federation ([Google Cloud: federation with deployment pipelines](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines)), in its own RFC or ADR.

### Enforcement

RFC 0002 enforces a rule with rulesets, Git hooks, CI checks and Conftest policies. Each Conftest rule has a test for a pass and a fail case.

**Prevention and detection.** The repository is public, so a commit is public when GitHub receives the push. Before the push, only SC2 prevents. At the push, only SC0 prevents, and "anyone with write access to the repository can bypass push protection by specifying a bypass reason" ([GitHub: about push protection](https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection)). The agents push as the owner, so they can bypass it too. Each bypass makes an alert and an audit log entry. SC1 only detects: a hit means "rotate the value at its issuer, then clean the PR".

| ID | Check | Tool | Rule | Level |
| --- | --- | --- | --- | --- |
| SC0 | Push protection | GitHub (exists, on) | Refuses a push with a turned-on pattern. Writers can bypass it. Refer to question 6. | Server |
| SC1 | Secret scan in CI | New `lint:secrets` in `mise run lint` | gitleaks scans the commits of the PR. `lint.yml` installs gitleaks and gets the full branch history. | Fail |
| SC1a | Full history | `gitleaks git`, one time | Scan all the history. A hit means a rotation. | One time |
| SC2 | Before the commit | pre-commit `gitleaks`, `detect-private-key` (exist) | Unchanged. | Fail |
| SC3 | age private key | `.gitleaks.toml` | Refuse `AGE-SECRET-KEY-1` and `keys.txt`. | Fail |
| SC4 | SOPS file encrypted | `lint:secrets` | `sops filestatus` gives `{"encrypted":true}` for each `*.sops.yaml`. | Fail |
| SC5 | SOPS recipients | `lint:secrets` | The recipients of each file equal its rule in `.sops.yaml`. | Fail |
| SC6 | `.sops.yaml` shape | Conftest `sops` | Anchored `path_regex`, the recovery key, no rule without `path_regex`. | Fail |
| SC7 | No Secret data in `gitops/` | Conftest `kubernetes` | No values in `data` or `stringData`, also when encrypted. `kubernetes/` keeps the current rule. | Fail |
| SC8 | No Sealed Secrets in `gitops/` | Conftest `kubernetes` | No `kind: SealedSecret`. | Fail |
| SC9 | ESO objects | Conftest `kubernetes` | An `ExternalSecret` refers to `SecretStore` `secrets`, or to a `ClusterSecretStore` `oc-*` from a cell namespace. No `dataFrom.find`. A `ClusterSecretStore` has a name `oc-<tenant>`, reads only `secret-seeds-oc-<tenant>`, and has `spec.conditions`. No `ClusterExternalSecret`, `PushSecret` or `ClusterPushSecret`. A `RoleBinding` in `secret-seeds-<c>` binds only the store ServiceAccount of `<c>`. | Fail |
| SC10 | Terraform secrets | Conftest `terraform` | No `data "sops_file"`. No values in `data` or `binary_data` of `kubernetes_secret_v1`. Each `data_wo` has a `data_wo_revision`. | Fail, after the move of `bootstrap-cert-manager` |
| SC11 | Secret resources in local state | Conftest `terraform` | Create the RFC 0005 policy if it is not on `main`. Add `google_apikeys_key` and `google_service_account_key`. | Fail |
| SC12 | Secret variables | Conftest `terraform` | `sensitive = true` also has `ephemeral = true`. | Fail, after the move of `bootstrap-cert-manager` |
| SC13 | No CI secrets | Conftest `actions` | No `secrets.<name>` except `GITHUB_TOKEN`, no `secrets: inherit`, no `toJSON(secrets)`. | Fail |
| SC14 | Required check | Ruleset on `main` (exists) | `Run every linter and check` is required. | Exists |
| SC15 | The path of the decrypted values | Conftest `terraform`, `--combine` | Refer to "The path of the decrypted values". | Fail |
| SC16 | kagent RBAC | Conftest `kubernetes` on `gitops/**/rendered/` | No `Role` or `ClusterRole` of the kagent tool server has `*` or `secrets`. No `RoleBinding` or `ClusterRoleBinding` binds a kagent ServiceAccount to a role that breaks this, also a built-in role such as `cluster-admin`, `admin` or `edit`. The controller gets `secrets` only in a `Role` in `kagent`, after question 8. | Fail |

SC7 changes the current rule: a SOPS-encrypted `Secret` no longer passes in `gitops/`, because no SOPS file goes there.

### Agents

The agents run as the user of the owner (RFC 0002, RFC 0005).

| Item | Agent can read | Control |
| --- | --- | --- |
| SOPS files, `.sops.yaml`, public keys | Yes | They are public |
| The age scope key in `keys.txt` | Yes, if it is a plain file | Question 3. A deny rule for agents is a convenience only. |
| The recovery key | No | Offline |
| The states and plans | Yes | No value in them: rules 2 to 7 and the dummy test |
| The Kind kubeconfig and the Secrets of `kind-local` | Yes | Low value: a test cluster and a free-tier key (question 2) |
| The plaintext during `sops edit` | Yes, during the edit, and in editor swap, backup or undo files | No agent session during the edit; an editor without those files |
| The plaintext during `secrets:apply` | Yes, if agent code sends it out | Only the owner applies, after the review; SC15 |
| CI logs | Yes | No secret in CI (SC13) |

Rules for the agents:

- Never run `sops decrypt`, `sops edit`, `sops exec-env`, `kubectl get secret -o yaml` or `secrets:apply`. Never read `keys.txt` or a `.tfstate` file.
- `mise run instance:up` stays permitted. It does not touch the seeds.
- No agent session runs while the owner edits a SOPS file or runs `secrets:apply`.
- Write the code around a secret, never the value. If a value shows in the output of an agent, the owner rotates it.

Only the agent identity RFC closes the gap.

## Security considerations

- **Where the Gemini key is.** One SOPS file in Git (ciphertext), the etcd of `kind-local` twice, and the memory of kagent. `kind-local` has no encryption at rest, and each user of the Docker socket can read etcd. This RFC accepts that for `kind-local`, because the kubeconfig of the owner already gives cluster administrator access. The `olympus` migration must turn it on.
- **The age key is the root.** Each process of the owner can read a plain `keys.txt`. Scope keys limit a leak to one file, and the recovery key is offline.
- **The edit.** The plaintext is in a temporary file during `sops edit`, and editors can keep copies.
- **Agent code runs with the plaintext.** The owner applies code that agents wrote. A hardware key does not stop exfiltration, because the owner touches it for that same apply. The controls are the separate secrets root module, SC15, and the review of the owner. A changed provider block or kubeconfig context can send the seeds to a different host, and only the review catches it.
- **Public ciphertext.** Git keeps old SOPS files forever. A leaked old key decrypts them. Thus each "recipient leaks" event also rotates the values at their issuer.
- **No secret in state.** Rollout step 6 proves it with a dummy value, after a refresh too.
- **Argo CD never decrypts.** No key goes into the repo server or Redis, and `rendered/` holds no Secret data.
- **ESO is privileged.** Its controller reads and writes each Secret. One store for each consumer keeps a consumer from the seeds of another. Only Argo CD creates ESO objects, and ESO cannot push a Secret out. The OpenChoreo stores of question 7 are the only cluster stores.
- **The kagent agents.** A prompt injection can send out each Secret that the role of the agent can read. SC16 and the requirements on RFC 0008 limit those roles.
- **The Gemini key.** A leak uses the quota of the project. On the free tier, Google may use the prompts, which hold cluster data of `kind-local`. On the paid tier, a leak can make charges.
- **CI and leaks.** No secret in GitHub Actions. Push protection and pre-commit are the only controls before publication, and writers, also agents, can bypass push protection.
- **Supply chain.** `sops`, `age`, the `carlpett/sops` provider and the ESO chart get exact pins. A malicious `sops` binary or provider sees all values.
- **The legacy tree.** Sealed Secrets on `olympus` do not change until the migration.

## Rollout

Each step keeps `main` green.

1. The owner decides on this RFC. The author sets the final status when the owner asks, and the owner merges.
2. The author derives the ADRs in a new PR, for example: SOPS and age with scope and recovery keys; ephemeral resources and write-only arguments; seed namespaces and one store for each consumer; a separate secrets root module that only the owner applies; the Gemini API key for M1; no CI secrets; the SC checks.
3. **Tooling PR.** Pin `sops` and `age`. Add `.sops.yaml` with public keys only. The owner makes the recovery key and the `kind-local` scope key. Add `secrets:edit`, with the editor settings, `secrets:apply` and `secrets:rotate`.
4. **`bootstrap-cert-manager` PR.** Move to `data_wo` and an ephemeral variable. After it, no file on `main` breaks SC10 or SC12.
5. **Enforcement PR, before any secret.** Add SC1, SC3 to SC13, SC15 and SC16 with tests, `policy/data/secrets.yaml` and `.gitleaks.toml`. Create the RFC 0005 policy for SC11 if it is not on `main`. Run SC1a. Update `docs/reference/policies.md` and rule 4 of `AGENTS.md`.
6. **Secrets root module PR.** Add `modules/bootstrap-secret-seeds/` and `instances/kind-local/secrets/` with a **dummy** value. The owner runs `secrets:apply`, then the checks of the dummy test in the verify list. Only after they pass does the owner put the real key in. If they fail, the real key does not go into Terraform: refer to the fallback in the verify list.
7. **ESO PR.** Add `gitops/infrastructure/external-secrets/` with an empty consumer list, and add it to `cluster.yaml`. Check: the ESO pods are ready.
8. **M1 PR (RFC 0008).** Add `kagent` to the consumer list, the kagent component with its `ExternalSecret`, and the pinned chart. It merges only when SC16 passes on the rendered kagent component. Check: `kubectl -n kagent get secretstore secrets` shows a valid store, the `ExternalSecret` is in sync, and an agent answers with Gemini.
9. **Documentation PR.** Rewrite `docs/explanation/secret-management.md` and `docs/how-to/manage-secrets.md`, or mark them as legacy for `kubernetes/`. Add "Add a secret" and "Rotate a secret".

Milestone acceptance criteria, in the format of RFC 0002:

```text
1. No Secret in Git has data that is not encrypted.
   Check: `mise run lint:policy` passes in CI.
2. No commit of a PR adds a secret.
   Check: `mise run lint:secrets` runs gitleaks in CI.
3. No state holds a secret value.
   Check: the dummy test of rollout step 6.
4. kagent on kind-local reads the Gemini key from ESO.
   Check: `kubectl -n kagent get externalsecret kagent-gemini` shows the Secret in sync.
5. The kagent tools cannot read Secrets.
   Check: SC16 passes in CI.
```

To go back: delete the `ExternalSecret`, and ESO deletes `kagent-gemini`. `terraform destroy` on the secrets root module deletes the seeds. The SOPS file can stay.

### Verify in the implementation PR

- **SOPS.** It refuses a file that matches no rule. The `filestatus` output in 3.13.3. The ephemeral resource reads `SOPS_AGE_KEY_FILE`, `SOPS_AGE_KEY_CMD` and age plugins, and how it fails without a TTY. The provider example writes `data.sops_file` for the ephemeral resource; use `ephemeral.sops_file`. The editor of `secrets:edit` and its settings.
- **Terraform.** A module variable that is ephemeral feeds `data_wo` through `for_each`. `data_wo_revision = parseint(substr(filesha256(<file>), 0, 8), 16)` is valid. A refresh does not fill `data` when only `data_wo` is set; the 3.1.0 page still says "All arguments including the secret data will be stored in the raw state as plain-text". An `action` block can or cannot read an ephemeral value. SC15 can find each reference with the HCL parser of Conftest, which gives expressions as strings.
- **The dummy test.** `secrets:apply`; `terraform plan -refresh-only -out=<file>` and `terraform show -json <file>`; `terraform apply -refresh-only`; `terraform show -json`. Search for the dummy and for its base64 form in the state, its backup, the saved plan and each output. **Fallback** if a search finds it: delete the state and the plan file, rotate nothing (it is a dummy), and keep the real key out of Terraform. The owner then creates the seed by hand from the SOPS file, for example `sops decrypt --extract '["gemini-api-key"]' <file> | kubectl -n secret-seeds-kagent create secret generic gemini-api-key --from-file=value=/dev/stdin`, until a fix or the remote backend exists.
- **The secrets root module.** The schema and lint checks accept `instances/<instance>/secrets/`. Its provider reads the kubeconfig context of the instance.
- **ESO.** The store fields (`remoteNamespace`, `server.caProvider`, `auth.serviceAccount.name`). A store ServiceAccount in the consumer namespace reads the seed namespace through a `RoleBinding` there. `createPushSecret` and `createClusterPushSecret` are under `crds.`, and each `crds.create*: false` needs the matching `process*: false`. `crds.createClusterExternalSecret: false` removes that CRD. `processClusterGenerator`. `spec.conditions` with a namespace label selector, for the `oc-*` stores. The forced refresh annotation and the status names. `deletionPolicy: Retain` keeps the consumer Secret when its seed goes away. The ESO Application syncs a store before its consumer namespace exists, or retries.
- **ESO 2.14 on Kubernetes 1.36** (`kind-local`). Else pin 2.13.
- **Argo CD.** No `OutOfSync` on a Secret that ESO owns. `SkipDryRunOnMissingResource=true` on a store before the CRDs exist.
- **kagent.** How an agent pod gets the key, and if it reloads it. Chart 0.10.4 has `providers.gemini` with `apiKeySecretRef: kagent-gemini` and `apiKeySecretKey: GOOGLE_API_KEY`, and renders a Secret only when `apiKey` is set. `main` moved `ModelConfig` to `kagent.dev/v1alpha3`. The controller works with `rbac.namespaces: [kagent]` and with `kagent.rbac.validate`. The auth value is `controller.auth.mode` in 0.10.4, and `config.server.auth.mode` on `main`.
- **OpenChoreo.** The label that marks the cell namespaces of a tenant, and how a tenant selects its `oc-<tenant>` store, because `SecretStoreRef` has only a name.
- **GitHub.** Delegated bypass for push protection on this plan.
- **Gemini.** The name of the API restriction, and the free tier limits and terms on `ai.google.dev`, which this RFC did not read.
- **gitleaks 8.30.1.** The command for the commit range of a `pull_request` merge ref, and a built-in rule for age keys.
- **Costs not read.** AWS Secrets Manager prices and the KMS cost of an SSM `SecureString`. The Azure Key Vault free tier: community answers say 10,000 transactions a month for 12 months ([Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/5608202/how-to-correctly-estimate-azure-key-vault-cost)). The free tiers of Bitwarden, Infisical and 1Password. If Cloud KMS Autokey fits SOPS.

## Drawbacks

- Each secret change needs the owner at the keyboard: `sops edit` and `secrets:apply`.
- A test that needs the Gemini key waits for the owner. A re-created `kind-local` has no seeds until the owner applies again.
- ESO adds parts that one `kubectl create secret` does not need. They pay back when a cloud backend comes.
- One seed namespace and one store for each consumer add objects. Two copies of each value are in etcd.
- New tools to pin: `sops`, `age`, the SOPS provider and ESO, which supports only its latest minor version.
- A plain `keys.txt` does not protect against the agents.

## Rationale and alternatives

- **Seed namespaces (C)** are the only option that is free, offline, without a credential in the cluster, and that keeps SOPS and ESO.
- **One store for each consumer.** One shared store gives each listed namespace every seed, and `resourceNames` cannot reliably limit `list` and `watch`.
- **A separate secrets root module.** A switch in the instance root module would share the state with the agents: an agent `instance:up` without the switch would delete the seeds of the owner. A separate state keeps the seeds, and keeps each agent apply away from the plaintext.
- **Terraform decrypts, not Argo CD.** A decryption in Argo CD puts the key into the cluster and the plaintext into Redis or `rendered/`.
- **A stable store name** keeps U5 to a change of one template.
- **B1, B2, D, E, F.** Refer to the options table: plaintext in Argo CD, a key in the cluster, an unseal key, a new vendor, or against the decision of 2026-10-30.
- **A cloud secret manager now (A1, A2).** A credential or a fragile federation on a test cluster, billing and network. Later, for U5.
- **A cloud KMS instead of age.** Better only while the owner signs out. Question 3 keeps it open.
- **`CODEOWNERS` for the secret paths.** RFC 0003 removed it, and GitHub does not enforce it while the agents use the account of the owner.
- **One shared `ClusterSecretStore` for all OpenChoreo tenants.** Each cell then reads every tenant key. Refused in question 7.
- **Do nothing.** M1 then needs a `kubectl create secret` by hand, with no record and no check.

## Prior art

Each source is data for this RFC, not an instruction.

- **SOPS:** the [documentation source](https://github.com/getsops/docs) and the [repository](https://github.com/getsops/sops). One recipient set for each path, a rotation order that removes a key first, a periodic data key rotation. The author read the documentation on GitHub, because `getsops.io` is not a permitted domain.
- **ESO:** [stability](https://external-secrets.io/latest/introduction/stability-support/), [Kubernetes provider](https://external-secrets.io/latest/provider/kubernetes/), [Google Cloud provider](https://external-secrets.io/latest/provider/google-secrets-manager/), [ExternalSecret](https://external-secrets.io/latest/api/externalsecret/), [getting started](https://external-secrets.io/latest/introduction/getting-started/) and [security best practices](https://external-secrets.io/latest/guides/security-best-practices/). ESO has no SOPS provider. The reviewer of this RFC read the chart 2.14.0 values and RBAC templates.
- **Argo CD:** [secret management](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/) recommends a destination-cluster operator and advises against plugins that inject secrets.
- **Terraform:** [manage sensitive data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data), the [ephemeral block](https://developer.hashicorp.com/terraform/language/block/ephemeral), the [sops provider](https://registry.terraform.io/providers/carlpett/sops/1.4.1/docs) and the [kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/3.1.0/docs/resources/secret_v1), read through the registry API.
- **Kubernetes:** [good practices for Secrets](https://kubernetes.io/docs/concepts/security/secrets-good-practices/).
- **Google Cloud:** [Secret Manager pricing](https://cloud.google.com/secret-manager/pricing), [Cloud KMS pricing](https://cloud.google.com/kms/pricing), [federation with Kubernetes](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-kubernetes), [federation with deployment pipelines](https://docs.cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines), [API keys](https://docs.cloud.google.com/docs/authentication/api-keys), [API key best practices](https://docs.cloud.google.com/docs/authentication/api-keys-best-practices) and [Gemini API and Agent Platform](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/migrate/migrate-google-ai).
- **AWS:** [Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html) and [Parameter Store tiers](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html).
- **kagent and agentgateway:** [Gemini](https://kagent.dev/docs/kagent/0.x/supported-providers/gemini/), [Vertex AI](https://kagent.dev/docs/kagent/0.x/supported-providers/google-vertexai/), [agentgateway](https://kagent.dev/docs/kagent/0.x/supported-providers/byo-agentgateway/), [API reference](https://kagent.dev/docs/kagent/0.x/resources/api-ref). The reviewer read [agentgateway: Gemini](https://agentgateway.dev/docs/kubernetes/latest/llm/providers/gemini/) and the charts of `kagent-dev/kagent` 0.10.4 and `kagent-dev/tools`.
- **OpenChoreo:** the reviewer read `openchoreo/openchoreo` 1.3.3 and [OpenChoreo: secret management](https://openchoreo.dev/docs/platform-engineer-guide/secret-management/). `SecretStoreRef` names a `ClusterSecretStore`, and "All OpenChoreo planes reference this single store".
- **GitHub:** [about push protection](https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection), read by the reviewer.

The author did not read `getsops.io`, `age-encryption.org`, `ai.google.dev`, the AWS and Azure price pages, or the repositories of gitleaks, KSOPS, helm-secrets, Bitwarden, Infisical and 1Password. The verify list holds the claims that depend on them.

## Unresolved questions

The owner decides these questions in the review of this RFC.

### 1. The ESO backend

- (a) Seed namespaces now, on each cluster. Free and offline.
- (b) GCP Secret Manager now, also on `kind-local`. Billing, federation with a new JWKS for each Kind cluster, network.
- (c) (a) now, and (b) for each cloud instance, behind the same store name.

Recommendation: **(c)**.

### 2. The Gemini access for M1

- (a) Gemini API key, free tier. A leak costs no money. Google may use the prompts.
- (b) Gemini API key, paid tier, with a budget (RFC 0005 G2). The prompts stay private.
- (c) Vertex AI with a service account identity. On Kind it needs a key file or federation.
- (d) Vertex AI express mode key: 90 days free, then billing.

Recommendation: **(a) for M1 on `kind-local`**, which holds only test data. (b) before kagent reads data from `olympus` or from a person. (c) with Workload Identity on GKE later.

### 3. The place of the age scope key

- (a) A plain `keys.txt`. Each agent can read it.
- (b) A passphrase. Terraform may not prompt for it.
- (c) A hardware key through an age plugin: a touch for each decryption. Not tested with Terraform.
- (d) A cloud KMS key with a short sign-in for each apply.

None of them stops agent code inside the apply of the owner. Recommendation: **(a) for `kind-local` now**, with the offline recovery key. **(c) before a production value goes into SOPS.**

### 4. Provider account tokens in SOPS

- (a) No, as in RFC 0005: short-lived tokens for each apply session.
- (b) Yes, with one scope key for each account. The key on the machine then gives the agents an edit token.

Recommendation: **(a)** until the agent identity RFC.

### 5. The scope of the age keys

- (a) One scope key for each SOPS file, plus one recovery key.
- (b) One key for all.

Recommendation: **(a)**.

### 6. The non-provider patterns of secret scanning

- (a) Turn them on: push protection also covers generic patterns. Maybe more false alerts.
- (b) Keep them off.

Recommendation: **(a)**. Push protection is the only control on the server before publication, even if writers can bypass it.

### 7. The stores for OpenChoreo

OpenChoreo 1.3.3 refers to an ESO `ClusterSecretStore` by name only, its samples set `kind: ClusterSecretStore`, and it creates the cell namespaces (`dp-*`) at run time. A namespaced store cannot exist in a cell namespace before OpenChoreo creates it.

- **(A) One `ClusterSecretStore` for each tenant, named `oc-<tenant>`.** Each reads only `secret-seeds-oc-<tenant>`, and its `spec.conditions` limit it to the cell namespaces of that tenant, by label. Tenants do not read the keys of other tenants. SC9 permits only `oc-*` names, each bound to its own seed namespace. `processClusterStore` stays `true`. RFC 0007 must select the store of each tenant.
- **(B) One shared `ClusterSecretStore` for all tenants.** Simple, but each cell reads every tenant key. Refused.
- **(C) A namespaced store in each `dp-*` namespace.** Something must create the store and its RBAC when OpenChoreo creates the namespace, for example the cluster agent or a policy engine. The OpenChoreo API documents no namespaced store, so this path has no upstream support.
- **(D) Defer.** No cluster store until RFC 0007 decides. M2 then has no secrets.

Recommendation: **(A)**. It isolates the tenants and resolves RFC 0007 question 14.

### 8. The RBAC of the kagent controller

The upstream controller role of chart 0.10.4 reads and writes all core resources in all namespaces, so it fails SC16.

- (a) Limit the controller to `rbac.namespaces: [kagent]`, if the chart supports it. The controller then reads only the Secrets of `kagent`.
- (b) A bounded exception for `kind-local`: SC16 permits the upstream controller role there, with a record, until (a) or (c).
- (c) Carry a patch of the upstream role in the kagent component, or propose it upstream.

Recommendation: **(a)**, with (b) only if the verify step shows that kagent does not work with namespaced RBAC. RFC 0008 owns the values and must meet the result.

### Dependencies on other RFCs

- **[RFC 0002](0002-how-we-work.md)**: the four controls, the required check, the review policy, the agent identity gap.
- **[RFC 0003](0003-repository-structure.md)**: the tree. This RFC adds `instances/<instance>/secrets/`, `.sops.yaml`, `modules/bootstrap-secret-seeds/` and `gitops/infrastructure/external-secrets/`. No `CODEOWNERS`.
- **[RFC 0004](0004-labels-and-annotations.md)**: the required keys on the seed namespaces and ESO objects.
- **[RFC 0005](0005-repository-scope-and-naming.md)**: the state rules and decision 5. This RFC adds `google_apikeys_key` to its list.
- **RFC 0007 (OpenChoreo)**, in draft: the `oc-<tenant>` stores of question 7, and its question 14.
- **RFC 0008 (kagent and agentgateway)**, in draft: the requirements on kagent, SC16, question 8, the place of the Gemini key, and `controller.auth`.
- **The tooling RFC**: the remote backend.
- **The agent identity RFC**: closes the agent gap.

## Future possibilities

- GCP Secret Manager behind the stores on a GKE instance, with Workload Identity (U5).
- ESO generators for values that no person needs to know.
- A plan in CI with GitHub OIDC, after the agent identity RFC.
- SOPS key groups with a Shamir threshold, if a second person gets access.
- A scheduled check of the age of each key and value.
- The removal of the SOPS format check in `policy/kubernetes/kubernetes.rego` after the Sealed Secrets migration.
