# Provider accounts

This page lists the scope rule of the repository, the layout of the provider accounts, the state requirements, the credentials, the budgets and the naming rules. The reasons are in [Repository scope (explanation)](../explanation/repository-scope.md).

## Scope rule

An item belongs in the repository when all three conditions are true:

1. **It changes with the infrastructure.** A change of the item and a change of a cluster or an account often occur in the same PR.
2. **It deploys to the same targets.** The targets are the clusters of the instances and the provider accounts of this repository.
3. **It follows the same review flow.** An atomic PR, a review, a plan or a render in the PR, and a manual merge ([How we work](how-we-work.md)).

If one condition is false, the item goes into a different repository.

| Item | In scope | Reason |
| --- | --- | --- |
| Cloudflare zones, DNS records, tunnels, Zero Trust Access applications, the Worker | Yes | Provider account. A tunnel and its DNS record change with the cluster that it exposes. |
| AWS, GCP, Azure and Grafana Cloud accounts: budgets, IAM, projects, stacks | Yes | Provider accounts. |
| Self-hosted apps on `olympus`, for example Home Assistant | Yes | GitOps components on a cluster. |
| Talos and the Raspberry Pi nodes, Kind, GKE and AKS instances | Yes | Instances. |
| The registration of `gsuquet.com` | Partly | The zone and its records are in scope. The Cloudflare provider 5.28.1 lists no resource for the registration, so the registration stays a manual item. |
| Dotfiles (`gsuquet/dotfiles`) | No | They deploy to a workstation, not to a cluster or an account. |
| Windows machine setup (`gsuquet/choco-setup`) | No | Same reason. |
| A tool with its own release cycle, for example the reusable workflows (`gsuquet/workflows`, later `gsuquet/.github`) | No | It has versions and tags of its own, and other repositories call it. |
| The source code of an app | No | The [Argo CD best practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/) keep the configuration separate from the application source code. |
| Agent skills and hooks | Not decided | The agents design decides their place later. |

## Layout

A **provider account** is one account at a provider: one Cloudflare account, one AWS account, one GCP billing account with its projects, one Azure subscription, one Grafana Cloud organization. An **account root module** is the Terraform root module that manages one provider account. It is a "composition" in the terms of [terraform-best-practices.com](https://www.terraform-best-practices.com/key-concepts).

```text
(the root of the repository)
├── accounts/<account>/        # [not yet] Terraform root modules, one for each provider account
│   ├── account.yaml           # Metadata. schemas/account.schema.json [not yet] validates it.
│   ├── README.md              # Purpose, manual items, and the generated terraform-docs block
│   ├── terraform.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── imports.tf             # The import blocks, during an import
│   └── .terraform.lock.hcl
├── modules/<layer>-<component>/
├── instances/<instance>/
├── gitops/
└── ...                        # The rest of the tree
```

- The accounts: `accounts/cloudflare/`, `accounts/aws/`, `accounts/gcp/`, `accounts/azure/` and `accounts/grafana-cloud/`.
- The folder name is the product name in a DNS-1123 label. A second account at the same provider gets a suffix, for example `accounts/aws-sandbox/`.
- An account root module holds its resources directly, without child modules. When two root modules need the same group of resources, a module with the new layer `account` goes into `modules/`, for example `modules/account-budget-alerts/`. That change adds `account` to the `layer` enum of `schemas/module.schema.json`.

### `account.yaml`

```yaml
apiVersion: infra.gsuquet.com/v1alpha1
kind: Account
name: cloudflare
provider: cloudflare        # cloudflare | aws | gcp | azure | grafana-cloud
purpose: production         # production | test | demo, as in instance.yaml
description: The Cloudflare account, with the zone gsuquet.com.
state:
  backend: local            # The enum of instance.schema.json: r2 | hcp-terraform | local
```

`schemas/account.schema.json` [not yet] validates it:

- `name` equals the folder name, and it starts with the value of `provider`.
- The `purpose` and `state.backend` enums are the enums of `instance.schema.json`.
- The budget values go into the `.tf` files, not into the metadata, because a Conftest policy reads the Terraform code.

### Which root module owns a resource

| Lifecycle of the resource | Root module | Examples |
| --- | --- | --- |
| As long as the account | `accounts/<account>/` | The zone `gsuquet.com`, the MX records, a budget, an Access application |
| As long as one instance | `instances/<instance>/` | A GKE cluster, a tunnel that only one cluster uses, the DNS record that points to that tunnel |

- An instance reads the values of an account (for example the zone ID) through a data source or an input variable, never through `terraform_remote_state` ([HashiCorp: remote state data source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)).
- The `olympus` tunnel and its DNS records go into `accounts/cloudflare/` until `instances/olympus/` exists. Their import waits for the remote backend. After the migration, they move to `instances/olympus/` ([Import provider resources](../how-to/import-provider-resources.md#move-a-resource-to-another-root-module)).

## Terraform state

These requirements apply to each root module, in `accounts/` and in `instances/`:

| ID | Requirement | Reason |
| --- | --- | --- |
| S1 | One state for each root module. | The [HashiCorp style guide](https://developer.hashicorp.com/terraform/language/style). A failure affects one account only. |
| S2 | The state is not only on one machine. It has versions, and an earlier version can be restored. | A disk failure or a wrong command must not lose the state. |
| S3 | Encryption at rest. Access only for the GitHub account `gsuquet` and the local machine of that account. No access for agents or CI. | The state holds secrets in plain text. |
| S4 | State locking. | Two runs at the same time can damage the state. |
| S5 | The backend stays inside a free tier, on a plan that does not end. | A trial that ends and deletes its resources must not hold the state. |
| S6 | Credentials for the backend come from the environment, not from a file in Git. | The repository is public. |

- `schemas/instance.schema.json` permits the backends `r2`, `hcp-terraform` and `local`, and it refuses `local` for a production or a demo instance.
- The backend is not selected yet (#235). The recommendation: Cloudflare R2 through the `s3` backend if locking works on R2, else HCP Terraform Free.

**The exception for accounts.** `account.schema.json` permits `local` for a production account. The exception ends when the PR that adds the remote backend merges. That PR changes the schema to the rule of `instance.schema.json`, and it migrates each local state. While the exception is in force:

- An account root module imports only resources that hold no secret, for example the zones, the DNS records and the budgets.
- A Conftest policy refuses the resource types that hold a secret in the state, in each root module with `backend: local`. Examples: `cloudflare_zero_trust_tunnel_cloudflared`, `cloudflare_api_token`, `cloudflare_account_token`, `grafana_cloud_access_policy_token`, `aws_iam_access_key`, `google_service_account_key`.
- A backup of each local state stays outside of the repository. `.gitignore` blocks `*.tfstate`.

## Credentials

No credential goes into the repository.

| Provider | Credential | Scope |
| --- | --- | --- |
| Cloudflare | An API token in `CLOUDFLARE_API_TOKEN`. The provider marks `api_token` as sensitive, and it calls API keys "legacy". | Only the permissions and the zones that the root module needs. A token can have an IP address filter and a TTL ([Cloudflare: create a token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)). |
| AWS | A login with short-lived credentials. Never an access key of the root user. | The account. The login does not join AWS Organizations while the account is on the Free plan ([AWS: choosing a plan](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html)). |
| GCP | Application default credentials from `gcloud`. No service account key. | The projects and the billing account. |
| Azure | The login from `az login`. | The subscription. |
| Grafana Cloud | A Cloud access policy token in the provider argument `cloud_access_policy_token`. | Only the scopes of the root module. |

- Two token types for each provider: a **read token** for `plan`, and an **edit token** for `apply`, with a short TTL where the provider permits it.
- Until a secrets store exists, the tokens stay outside of the repository, and Terraform gets them through environment variables.
- A read token can be a secret too. The Cloudflare data source `cloudflare_zero_trust_tunnel_cloudflared_token` exists, and the permission that reads a tunnel token is not verified.

### Who applies

- `plan` and `apply` on an account root module run by hand, outside of agent sessions. The plan goes in the PR. No CI job applies an account change. An agent never applies, and agents get no provider token.
- No edit credential stays where an agent can read it. For Cloudflare and Grafana Cloud: a short-lived token for one apply session, revoked after it.
- For GCP, Azure and AWS: one sign-in for one apply session, and a sign-out after it: `gcloud auth application-default revoke`, `az logout`, and `aws sso logout` or the equivalent of the AWS login method. Short-lived impersonation is a valid alternative.
- No agent session runs during an apply session.

### Account rules

These rules apply to each provider account, and first to the Cloudflare account, which holds the registrar and the DNS:

- Multi-factor authentication is on.
- The recovery email is not an address on `gsuquet.com`. Else a loss of the DNS also stops the recovery of the account.
- The registrar lock and the auto-renewal of `gsuquet.com` are checked by hand, because Terraform does not manage them. An expired domain loses the DNS and the email.
- The old repository name `gsuquet/homelab` is never used again after the rename. Agent permissions deny `gh repo create`.

## Free-tier guardrails

| ID | Rule | Check |
| --- | --- | --- |
| G1 | [not yet] `accounts/aws/` has an `aws_budgets_budget`, `accounts/gcp/` has a `google_billing_budget`, `accounts/azure/` has an `azurerm_consumption_budget_subscription`. Each has an actual and a forecast threshold, and it sends an email to the account email address. | A Conftest policy on `accounts/<provider>/`. |
| G2 | The budget comes in the first PR of the account, before any other resource. | The review. |
| G3 | Each paid plan, each removal of a spending limit and each paid product is a manual decision, outside of agent sessions. A budget exists first, where the provider has one. | The review. |
| G4 | Long-lived resources, for example the state backend, do not go on a plan that ends and deletes its resources. | Requirement S5. |

- Cloudflare and Grafana Cloud get no budget resource. Their providers (5.28.1 and 4.53.0) have no resource with "budget", "billing", "spend" or "usage" in its title. G3 is their guardrail.
- Plans: free plans for experiments, paid plans with budgets from the first commit for long-lived items.

## Drift detection

- [not yet] A mise task, for example `accounts:drift`, runs `terraform plan -detailed-exitcode` on each account root module, each week, by hand on the workstation. The exit code is 0 with no change, 1 for an error and 2 when the plan has changes ([HashiCorp: plan](https://developer.hashicorp.com/terraform/cli/commands/plan)).
- `terraform plan -refresh-only` shows only the changes outside of Terraform.
- A scheduled workflow comes only after the remote backend, a secrets store and an agent identity.

## Naming

| Use | Value |
| --- | --- |
| Repository | `gsuquet/infra` |
| API group of the metadata files | `infra.gsuquet.com/v1alpha1`. `schemas/` checks it. |
| Kubernetes labels and annotations | `<subgroup>.infra.gsuquet.com/<name>` ([Labels and annotations](labels-and-annotations.md)) |
| Cloud labels and tags (GCP, Azure, AWS) | The mechanical form, for example `instance_infra_gsuquet_com_name` |
| Cloudflare DNS record tags | `<cloud key>:<value>` in `tags`, for example `instance_infra_gsuquet_com_name:olympus` |
| Grafana Cloud stack labels | The cloud key form in `labels` |

- A new key, tag or link uses `infra` in its name. No new name uses `homelab`.
- The GitOps group `infrastructure` keeps its name.

## Open work

| Item | Issue |
| --- | --- |
| The rename of the repository, R0 to R7 | #230 |
| `account.schema.json`, the `accounts/` checks, the G1 policy and the local-state secret policy | #231 |
| `accounts/cloudflare/`: the zones and the DNS records | #232 |
| `accounts/aws/`, `accounts/gcp/`, `accounts/azure/`: the budgets first | #233 |
| `accounts/grafana-cloud/`: the stack and the access policies | #234 |
| The choice of the state backend, with a spike on R2 locking | #235 |
| The move to the remote backend, and the import of the resources with secrets | #236 |
| The weekly drift check task | #237 |
| The rewrite of [Configure Cloudflare](../how-to/configure-cloudflare.md) for the code | #238 |
