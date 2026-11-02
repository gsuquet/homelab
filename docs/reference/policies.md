# Policies

The policies are Conftest rules in Rego, in `policy/`. Each folder is one policy namespace. `mise run lint:policy` runs them.

| Folder | Namespace | Files | Tests |
| --- | --- | --- | --- |
| `policy/terraform/` | `terraform` | `terraform.rego` | `terraform_test.rego` |
| `policy/kubernetes/` | `kubernetes` | `kubernetes.rego` | `kubernetes_test.rego` |
| `policy/precommit/` | `precommit` | `precommit.rego` | `precommit_test.rego` |
| `policy/mise/` | `mise` | `mise.rego` | `mise_test.rego` |
| `policy/data/` | None | `labels.yaml`: the data of the label checks. The policies read it as `data.labels`. | None |

## Levels

Each rule has one of two levels ([Conftest: options](https://www.conftest.dev/options/)):

| Level | Rego rule | Effect |
| --- | --- | --- |
| Error | `deny` | Conftest prints the message, and `lint:policy` fails. |
| Warning | `warn` | Conftest prints the message. `lint:policy` does not fail, because the task does not use `--fail-on-warn`. |

## `lint:policy`

The task runs these commands from the root of the repository:

1. `conftest verify --policy policy --data policy/data`: the unit tests of all the namespaces.
2. `conftest test --no-color --policy policy --data policy/data --namespace <namespace>`, one time for each namespace, on the files that Git tracks:

| Namespace | Options | Input files |
| --- | --- | --- |
| `terraform` | `--combine --parser hcl2` | `*.tf` |
| `kubernetes` | `--combine` | `kubernetes/*.yaml` and `gitops/*.yaml`, except `gitops/*/sources/templates/*` |
| `precommit` | None | `.pre-commit-config.yaml` |
| `mise` | None | `.mise/config.toml` |

The patterns are Git pathspecs, so `*` also matches `/`. A Helm template in `sources/templates/` is not YAML before the render, so the `kubernetes` namespace reads the rendered files. When a namespace has no input file, the task prints a warning and continues.

The `lint-policy` pre-commit hook and the `lint` task run `lint:policy`.

## `terraform`

All the rules are `deny`.

| Input | Rule |
| --- | --- |
| A file with `modules/` at the start of its path, or with `/modules/` in its path | The file has no `provider` block. The root module configures the providers. |
| Each entry of `required_providers` | The entry has a `source`. |
| Each entry of `required_providers` | The `version` is one exact version: `x.y.z`. |

## `kubernetes`

All the rules in this section are `deny`. A rendered file is a file with `/manifests/` or `/rendered/` in its path.

| Input | Rule |
| --- | --- |
| Each container and init container of a `Pod`, `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `ReplicaSet` or `CronJob` | The image has an explicit tag, and the tag is not `latest`. |
| The same images, in a file that is not rendered | The image ends with a `sha256` digest: `@sha256:<64 hex digits>`. |
| Each `Application` in `gitops/` | `spec.source.targetRevision` is `main`. |
| Each `Application` in `gitops/` | `spec.syncPolicy.syncOptions` has no `CreateNamespace=true`. |
| Each `Application` in `gitops/` | No finalizer starts with `resources-finalizer.argocd.argoproj.io`. |
| Each `Namespace` in `gitops/` | The labels `pod-security.kubernetes.io/enforce`, `audit` and `warn` are `privileged`, `baseline` or `restricted`. |
| Each `Namespace` and `CustomResourceDefinition` in `gitops/` | The annotation `argocd.argoproj.io/sync-wave` is `"-2"` on a `Namespace` and `"-1"` on a CRD. |
| Each `Secret`, also in a multi-document file and in the `items` of a `List` | `data` and `stringData` have no values, or SOPS encrypts the `Secret`: a `sops` object with a `version`, and each value starts with `ENC[AES256_GCM,`. |

The `Secret` rule is a guard against accidents, not a security control.

### Label and annotation checks

The `kubernetes` namespace also has the checks K1 to K10, K14 and K15, and the checks of `policy/data/labels.yaml`. Some are `deny`, and some are `warn`. Each message has the ID of its check. The inputs, the rules, the levels and the allowlists are in [Labels and annotations](labels-and-annotations.md#checks).

## `precommit`

All the rules are `deny`.

| Input | Rule |
| --- | --- |
| Each item of `repos`, except `local` and `meta` | `rev` is a commit SHA of 40 hex digits. |
| Each `additional_dependencies` entry of a hook | The entry ends with an exact version: `@x.y.z` or `==x.y.z`. |

## `mise`

All the rules are `deny`.

| Input | Rule |
| --- | --- |
| Each tool in `[tools]` | The version is exact: three numbers, with an optional `v` before them and an optional suffix, for example `-rc.1`. A tool with an object value uses its `version` field. |
| `[settings]` | `lockfile` is `true`. |

## Related pages

- [Labels and annotations](labels-and-annotations.md): the label checks of the `kubernetes` namespace.
- [Mise tasks](mise-tasks.md): the `lint` and `lint:policy` tasks.
- [GitOps layout](gitops-layout.md#checks): the checks of the `gitops/` tree.
- [Add or change a policy rule](../how-to/add-or-change-a-policy-rule.md)
- [Label a GitOps component](../how-to/label-a-gitops-component.md)
