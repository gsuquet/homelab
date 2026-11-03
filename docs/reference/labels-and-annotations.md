# Labels and annotations

This page lists the label and annotation keys of the repository and the checks that apply to them. The checks are Conftest policies:

| File | Content |
| --- | --- |
| `policy/data/labels.yaml` | The data of the checks: the prefix, the sub-groups and their keys, the required keys, the tenants of the components and the allowlists. `conftest --data policy/data` loads it as `data.labels`. |
| `policy/kubernetes/kubernetes.rego` | The checks of the Kubernetes objects, in the `kubernetes` namespace. Each message has the path of the file, then the ID of its check, for example `K4`. |
| `policy/kubernetes/kubernetes_test.rego` | A test for each case that a check permits and each case that it refuses. |

`mise run lint:policy` runs the tests, then the checks. In this page, `<p>` is the prefix of the repository, `infra.gsuquet.com`.

## Input of the checks

`lint:policy` gives these files to the `kubernetes` policies, in one `conftest --combine` run:

- the files that Git tracks and that match `gitops/*.yaml` or `kubernetes/*.yaml`;
- except the Helm templates, `gitops/*/sources/templates/*`.

A file that Git does not track is not an input.

An object with an `apiVersion` in the group `infra.gsuquet.com`, for example `cluster.yaml`, is not a Kubernetes object. The label checks ignore it, but K4, K14 and K15 read `gitops/clusters/<cluster>/cluster.yaml`.

### Origin of an object

`mise run manifests:render` writes each object of a component to `gitops/clusters/<cluster>/rendered/<component>/<kind>-<name>.yaml`, in lowercase.

| Origin | File name | Rule |
| --- | --- | --- |
| Upstream | `upstream--<kind>-<name>.yaml` | The second segment of the `# Source:` path of the object is `charts`, for example `argocd/charts/argo-cd/templates/argocd-cm.yaml`. |
| Hand-written | `<kind>-<name>.yaml` | Each other object in `gitops/`. |

`mise run schemas:check` makes sure that a chart cannot pass as upstream when it is not:

- Each dependency in `sources/Chart.yaml` has a `repository` that starts with `https://` or `oci://`.
- Git tracks no file in `gitops/*/*/sources/charts/`.
- Each component has `sources/templates/namespace.yaml`.

### Blocks of metadata

K1 to K7 read the keys of `metadata.labels` and `metadata.annotations` in each block of an object:

| Kind | Blocks | Kind of the block for K4 |
| --- | --- | --- |
| `Deployment`, `StatefulSet`, `DaemonSet`, `Job`, `ReplicaSet` | `metadata`, `spec.template.metadata` | The kind of the object, then `Pod` |
| `CronJob` | `metadata`, `spec.jobTemplate.metadata`, `spec.jobTemplate.spec.template.metadata` | `CronJob`, then `Job`, then `Pod` |
| Other kinds | `metadata` | The kind of the object |

K1 to K7 do not read selectors, for example `nodeSelector` or `namespaceSelector`. Only K8 reads `spec.selector`.

## Key syntax

Kubernetes applies the same key rules to labels and to annotations ([labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/), [annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)). K1 checks these rules on all the objects of the input.

| Part | Rule |
| --- | --- |
| Key prefix | Optional. A DNS subdomain of max. 253 characters, then `/`. It contains only lowercase letters, digits, `-` and `.`, and each DNS label starts and ends with a letter or a digit ([Kubernetes: names](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/)). |
| Key name | Mandatory. Max. 63 characters. It starts and ends with a letter or a digit. Between them: letters, digits, `-`, `_` and `.`. |
| Label value | A string of max. 63 characters, or empty. If not empty, it starts and ends with a letter or a digit. Between them: letters, digits, `-`, `_` and `.`. |
| Annotation value | A string. |
| Annotation size | The keys and values of the annotations of one block have max. 262144 characters. |

In YAML, a number or a boolean is not a string. `"-2"` and `"true"` are strings.

K1 adds two rules for the keys of the repository, the keys with the prefix `<p>` or `<subgroup>.<p>`:

- The key name uses lowercase letters, digits and `-` only.
- The label value uses lowercase letters, digits and `-` only, or is empty.

## Families of keys

| Family | Prefixes | A hand-written object can have it |
| --- | --- | --- |
| Kubernetes core | `kubernetes.io`, `k8s.io` and their subdomains | Only the keys of the K2 allowlist |
| Recommended labels | `app.kubernetes.io/` | Yes. K2 permits the prefix. |
| Tools | For example `helm.sh/`, `argocd.argoproj.io/`, `cert-manager.io/` | Yes |
| Repository | `<subgroup>.<p>/` | Only the keys of `data.labels`. Refer to K4. |
| No prefix | None | Only the keys of the K3 allowlist |

## Keys of the repository

A key of the repository has the form `<subgroup>.infra.gsuquet.com/<name>`. `data.labels.subgroups` defines six sub-groups. A key with the prefix `infra.gsuquet.com` and no sub-group does not exist.

| Key | Type | Kinds | Permitted values |
| --- | --- | --- | --- |
| `tenant.<p>/name` | Label | `Namespace` | The tenant of the component. Refer to [Tenants of the components](#tenants-of-the-components). |
| `ownership.<p>/owner` | Label | `Namespace` | `gsuquet` |
| `ownership.<p>/contact` | Annotation | `Namespace` | An `https://` URL with no space, or an address with one `@` and no space |
| `network.<p>/zone` | Label | `Namespace` | The `network.zone` values of the component |
| `network.<p>/exposure` | Label | `Namespace` | The `network.exposure` values of the component |
| `backup.<p>/policy` | Label | `Namespace`, `PersistentVolumeClaim` | None |
| `backup.<p>/retention` | Annotation | `Namespace`, `PersistentVolumeClaim` | None |
| `instance.<p>/name` | Label | None | `^[a-z0-9]+(-[a-z0-9]+)*$` |
| `instance.<p>/purpose` | Label | None | `production`, `test`, `demo` |
| `instance.<p>/lifecycle` | Label | None | `long-lived`, `ephemeral` |
| `instance.<p>/ttl` | Label | None | `^[1-9][0-9]*[hd]$`, for example `24h` or `7d` |
| `instance.<p>/type` | Label | None | `^[a-z0-9]+(-[a-z0-9]+)*$` |
| `cost.<p>/center` | Label | None | `^[a-z0-9]+(-[a-z0-9]+)*$` |

- "None" in the column "Kinds" means that no Kubernetes object can have the key. K4 refuses it on each object.
- "None" in the column "Permitted values" means that the list of values is empty. K4 refuses each value.
- The `instance` and `cost` keys have `cloud: true` in `data.labels`. `cloud: true` marks a key for cloud resources. No policy checks cloud resources.

### Tenants of the components

| Component | Group in `cluster.yaml` | Tenant |
| --- | --- | --- |
| An `infrastructure` component | `infrastructure` | `platform`, the value of `data.labels.platform_tenant` |
| An `apps` component | `apps` | `data.labels.components.<component>.tenant`. It is not `platform`. |

An `apps` component without an entry in `data.labels.components` has no tenant, so K4 refuses each `tenant.<p>/name` value on its `Namespace`. An entry has this form:

```yaml
components:
  <component>:
    tenant: <tenant>
    network:
      zone: []
      exposure: []
```

`network` is optional. Without it, the component has no permitted `network` value.

## Required keys

| Kind | Required labels | Required annotations | Check |
| --- | --- | --- | --- |
| `Namespace` in `gitops/` | `pod-security.kubernetes.io/enforce`, `audit` and `warn`, each `privileged`, `baseline` or `restricted` | `argocd.argoproj.io/sync-wave: "-2"` | Namespace checks, `deny` |
| `Namespace` in `gitops/` | `tenant.<p>/name`, `ownership.<p>/owner` | None | K5, `warn` |
| `CustomResourceDefinition` in `gitops/` | None | `argocd.argoproj.io/sync-wave: "-1"` | Sync wave check, `deny` |
| The pod template of a workload or a `CronJob` | `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/part-of` | None | K6 or K7, `warn` |
| The `metadata` block of each object in `gitops/` | `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/managed-by` | None | K6 or K7, `warn` |

`data.labels.required` holds the lists of K5, K6 and K7. It also holds `required.cloud`: `instance.<p>/name`, `purpose`, `lifecycle` and `type`, and `ttl` for an ephemeral instance. No policy reads `required.cloud`. The tests check that each of its keys is a label with `cloud: true`.

## Checks

| Check | Input | Rule | Level |
| --- | --- | --- | --- |
| K1 Syntax | All objects | The rules of [Key syntax](#key-syntax). | `deny` |
| K2 Reserved prefixes | Hand-written objects in `gitops/` | No key with the prefix `kubernetes.io`, `k8s.io` or one of their subdomains, except the K2 allowlist. | `deny` |
| K3 No prefix | Hand-written objects in `gitops/` | No key without a prefix, except the K3 allowlist. | `deny` |
| K3w No prefix | Upstream objects | The same rule as K3. | `warn` |
| K4 Keys of the repository | All objects in `gitops/` | Each key of the repository has a sub-group and a name of `data.labels`, the type of the key, a permitted kind and a permitted value. The K4 allowlist removes keys of upstream objects from the check. | `deny` |
| K5 Required keys of a Namespace | Each `Namespace` in `gitops/` | The labels of `data.labels.required.namespace`. | `warn` |
| K5 Platform tenant | `data.labels.components` | No component has the tenant `platform`. | `deny` |
| K6 Required keys of an object | Hand-written objects in `gitops/` | The labels of `required.object` in `metadata`, and of `required.pod_template` in a pod template. | `warn` |
| K7 Required keys in upstream charts | Upstream objects | The same rule as K6. | `warn` |
| K8 Stable selectors | `spec.selector.matchLabels` and `spec.selector.matchExpressions` of a workload, `spec.selector` of a `Service`, in `gitops/` | No key of `data.labels.unstable_keys`: `app.kubernetes.io/version`, `helm.sh/chart`. | `deny` |
| K9 Argo CD tracking | The `ConfigMap` `argocd-cm` in `gitops/` | `data` has `application.resourceTrackingMethod: annotation`. | `warn` |
| K10 Sync options | The annotation `argocd.argoproj.io/sync-options` of all objects in `gitops/`, and `spec.syncPolicy.syncOptions` of an `Application` | No option of `data.labels.forbidden_sync_options`: `Replace=true`, `Force=true`. The K10 allowlist permits options of upstream objects. | `deny` |
| K14 Pod Security of applications | Each `Namespace` of an `apps` component | `pod-security.kubernetes.io/enforce` is in `data.labels.apps_pod_security_levels`: `restricted` or `baseline`. The K14 allowlist permits other levels. | `deny` |
| K15 Namespace of a component | Each `Namespace` in `rendered/<component>/`, and `cluster.yaml` | The name of the `Namespace` is the `namespace` of the component in `cluster.yaml`. The K15 upstream allowlist permits other names. Two components of one cluster do not have the same namespace. An `apps` component does not use a namespace of the K15 reserved list. | `deny` |
| K16 Privileged containers | Each `Pod`, and the pod template of each workload and `CronJob`, in `kubernetes/` and `gitops/` | No container, init container or ephemeral container has `securityContext.privileged: true`, except in a namespace of `data.labels.allowlists.pod_security_privileged`. The namespace is `metadata.namespace`, or the `namespace` of the component in `cluster.yaml`. An object with no known namespace fails. | `deny` |
| K17 Enforcement scope | Each Tetragon `TracingPolicy` (`cilium.io/v1alpha1`) | No `matchActions` entry of a `kprobes`, `tracepoints`, `uprobes`, `lsmhooks` or `usdts` selector has the action `Sigkill`, `Override`, `Signal` or `NotifyEnforcer`. A cluster-wide policy acts on every process of the node. Put an enforcement policy in a `TracingPolicyNamespaced`. The action names are in [Tetragon: selectors](https://tetragon.io/docs/concepts/tracing-policy/selectors/). | `deny` |

"Workload" is a `Deployment`, a `StatefulSet`, a `DaemonSet`, a `Job` or a `ReplicaSet`. K6 and K7 also read the pod template of a `CronJob`. The legacy files in `kubernetes/` get only K1.

### Other checks of keys

`policy/kubernetes/kubernetes.rego` also has these checks. Each is `deny`, and the message has no check ID.

| Input | Rule |
| --- | --- |
| Each `Namespace` in `gitops/` | The labels `pod-security.kubernetes.io/enforce`, `audit` and `warn` are `privileged`, `baseline` or `restricted`. |
| Each `Namespace` and `CustomResourceDefinition` in `gitops/` | The annotation `argocd.argoproj.io/sync-wave` is `"-2"` on a `Namespace` and `"-1"` on a CRD. |
| Each `Application` in `gitops/` | `spec.syncPolicy.syncOptions` has no `CreateNamespace=true`. |
| Each `Application` in `gitops/` | No finalizer starts with `resources-finalizer.argocd.argoproj.io`. |

### Checks of the data file

These checks are `deny`. They check `policy/data/labels.yaml` itself.

- `data.labels` is not loaded: the message tells to run Conftest with `--data policy/data`.
- A key of `data.labels` that a check reads is missing or has the wrong type.
- `prefix`, `platform_tenant`, `subgroups`, `unstable_keys`, `forbidden_sync_options`, `apps_pod_security_levels`, the lists of `required` except `required.cloud.ephemeral_labels`, and `allowlists.reserved_namespaces` are empty.

## Allowlists

| Allowlist | Check | Content |
| --- | --- | --- |
| `allowlists.reserved_prefixes.keys` | K2 | `pod-security.kubernetes.io/enforce`, `audit`, `warn`, `kubernetes.io/metadata.name`, `kubernetes.io/os`, `kubectl.kubernetes.io/default-container` |
| `allowlists.reserved_prefixes.prefixes` | K2 | `app.kubernetes.io/`, `node-restriction.kubernetes.io/`, `gateway.networking.k8s.io/` |
| `allowlists.no_prefix` | K3, K3w | Empty |
| `allowlists.custom_keys_upstream` | K4 | Empty. Each entry: `{component, kind, name, key}`. |
| `allowlists.sync_options_upstream` | K10 | Empty. Each entry: `{component, kind, name, option}`. |
| `allowlists.pod_security_apps` | K14 | Empty. Each entry: a namespace name. |
| `allowlists.pod_security_privileged` | K16 | `tetragon`, `falco`. Each entry: a namespace name. |
| `allowlists.reserved_namespaces` | K15 | `default`, `kube-*`, `argocd`, `cert-manager`. Glob patterns. |
| `allowlists.upstream_namespaces` | K15 | Empty. Each entry: `{component, namespace}`. |

The entries of `custom_keys_upstream`, `sync_options_upstream` and `upstream_namespaces` apply only to upstream objects.

## Keys of other tools

### Recommended labels and Helm labels

| Key | Meaning | Example | Changes at an upgrade |
| --- | --- | --- | --- |
| `app.kubernetes.io/name` | The name of the application | `argocd-server` | No |
| `app.kubernetes.io/instance` | A unique name of the instance of the application. Helm uses the release name. | `argocd` | No |
| `app.kubernetes.io/version` | The version of the application | `v3.5.6` | Yes |
| `app.kubernetes.io/component` | The component in the architecture | `server` | No |
| `app.kubernetes.io/part-of` | The higher-level application | `argocd` | No |
| `app.kubernetes.io/managed-by` | The tool that manages the operation of the application | `Helm` | No |
| `helm.sh/chart` | The chart name and version: `{{ .Chart.Name }}-{{ .Chart.Version }}` | `argo-cd-10.11.6` | Yes |

Sources: [Kubernetes: recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/), [Helm: labels and annotations](https://helm.sh/docs/chart_best_practices/labels/).

`manifests:render` runs `helm template` with the component name as the release name, and with the `namespace` of the component in `cluster.yaml`. In a template of a component, `.Release.Name` is the component name, `.Release.Namespace` is its namespace, and `.Release.Service` is `Helm`.

### Argo CD annotations

| Key | Values in the repository |
| --- | --- |
| `argocd.argoproj.io/sync-wave` | `"-2"` on a `Namespace`, `"-1"` on a CRD, `"1"` or more on the `Application` of a component. The other objects have the default, `"0"`. |
| `argocd.argoproj.io/sync-options` | `Prune=false,Delete=false` on the `argocd` Namespace and on `argocd-secret`. `ServerSideApply=true,Prune=false` on the Argo CD CRDs. |

Each `Application` of a component has `ServerSideApply=true` in `spec.syncPolicy.syncOptions`. For the meaning of each option, refer to [Argo CD: sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/). For the order of the waves, refer to [Argo CD: sync waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/).

## Related pages

- [Label a GitOps component](../how-to/label-a-gitops-component.md)
- [Why the label scheme has its form](../explanation/why-the-label-scheme-has-its-form.md)
- [Policies](policies.md)
- [Add a GitOps component](../how-to/add-a-gitops-component.md)
