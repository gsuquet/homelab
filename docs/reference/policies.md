# Policies

This page lists the Conftest policies in `policy/`. The policies are written in Rego. The `lint:policy` task runs them.

## Rules

| Namespace | Files | Rule |
| --- | --- | --- |
| `terraform` | `*.tf` | A module in a `modules/` folder must not configure a `provider` block. Configure providers in the root module only. |
| `terraform` | `*.tf` | Each entry in `required_providers` must declare a `source`. |
| `terraform` | `*.tf` | Each entry in `required_providers` must use an exact version (`x.y.z`). |
| `kubernetes` | `kubernetes/**/*.yaml`, `gitops/**/*.yaml` | Each container image must have an explicit tag. The tag must not be `latest`. |
| `kubernetes` | Files that are not in a `manifests/` or `rendered/` folder | Each container image must also have a `sha256` digest. Rendered manifests come from upstream charts, so this rule does not apply to them. |
| `kubernetes` | Applications in `gitops/` | The Application syncs `main`. A branch can sync itself to test on Kind, but it cannot merge. |
| `kubernetes` | Applications in `gitops/` | The Application does not use `CreateNamespace=true`. Each component ships its own `Namespace`. |
| `kubernetes` | Applications in `gitops/` | The Application has no `resources-finalizer.argocd.argoproj.io` finalizer. When a component leaves `cluster.yaml`, its resources stay in the cluster. |
| `kubernetes` | Namespaces in `gitops/` | The labels `pod-security.kubernetes.io/enforce`, `audit` and `warn` are `privileged`, `baseline` or `restricted`. The annotation `argocd.argoproj.io/sync-wave` is `"-2"`. |
| `kubernetes` | CRDs in `gitops/` | The annotation `argocd.argoproj.io/sync-wave` is `"-1"`. |
| `precommit` | `.pre-commit-config.yaml` | Each hook repository must use a 40-character commit SHA as `rev`. `local` and `meta` repositories are not affected. |
| `precommit` | `.pre-commit-config.yaml` | Each `additional_dependencies` entry must use an exact version (`@x.y.z` or `==x.y.z`). |
| `mise` | `.mise/config.toml` | Each tool must use an exact version. |
| `mise` | `.mise/config.toml` | `settings.lockfile` must be `true`. |

## Tasks

| Task | Action |
| --- | --- |
| `mise run lint:policy` | Runs the unit tests (`conftest verify`), then checks the repository files. |

## Add or change a rule

1. Change the policy file in `policy/<namespace>/`.
2. Add a test in `policy/<namespace>/<namespace>_test.rego` for each case that must pass and each case that must fail.
3. Run `mise run lint:policy`.
4. Update the table on this page.
