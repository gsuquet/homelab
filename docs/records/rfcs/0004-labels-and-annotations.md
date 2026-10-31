---
rfc: "0004"
status: draft
start-date: 2026-10-31
pr: 169
---

# RFC 0004: Kubernetes labels and annotations reference

## Summary

This RFC proposes one set of rules for the labels and the annotations of the Kubernetes objects in this repository. It also covers the labels and tags of the cloud resources. It collects the syntax rules of Kubernetes, the recommended `app.kubernetes.io/*` labels, and the keys that Helm, Argo CD, Cilium, cert-manager and Gateway API use. It proposes a custom prefix of the form `<subgroup>.<prefix>.gsuquet.com/<name>` for the keys of the repository, but it gives options and does not select the prefix. It also proposes a mapping from the Kubernetes keys to Google Cloud labels and Azure tags, and the Conftest checks that enforce the rules. A reference table at the end can become a Diátaxis reference page later.

These subjects are out of scope. RFC 0002 covers the GitHub issue and PR labels, for example `kind/` and `area/`. RFC 0003 covers the structure of the repository. A later zero-trust RFC covers the design of the network policies.

## Motivation

The repository uses labels and annotations today, but it has no rule for them. Each upstream chart sets its own keys. The hand-written manifests in `kubernetes/` copy the recommended labels by hand. Only two Conftest rules check keys: the Pod Security labels on a `Namespace`, and the `argocd.argoproj.io/sync-wave` annotation on a `Namespace` and on a `CustomResourceDefinition`. Refer to [Inventory of the keys in use](#inventory-of-the-keys-in-use).

Later work needs a stable set of keys:

- **A zero-trust network policy.** Cilium makes a security identity from the labels of a pod. A policy selects pods by these labels. A label that changes at each upgrade gives a new identity. A label that an attacker can change can move a pod into a different policy. The later zero-trust RFC must know which labels are stable.
- **Tenants.** The repository will host applications of more than one tenant. A tenant key on each `Namespace` lets policies, quotas and reports select the objects of one tenant.
- **Cloud instances.** The demo and test instances on GKE and Azure create cloud resources. The owner must find, count and delete them. Cloud labels and tags do this, but their syntax is different from Kubernetes labels.
- **Argo CD.** Argo CD records which `Application` owns each object. A wrong tracking setting can make Argo CD delete objects that another tool owns.

Use cases:

- **An author adds a component in `gitops/`.** The author reads one reference table and knows which keys to set, on which kinds, with which values. `mise run lint` tells the author when a key is missing or wrong.
- **The owner writes a `CiliumNetworkPolicy`.** The owner selects pods with keys that do not change at an upgrade, and that only the repository sets.
- **The owner deletes a demo instance.** A query on one cloud label, the instance name, finds all the resources of that instance. The labels come from `instances/<name>/instance.yaml`.

## Proposal

### Label or annotation

A label identifies an object. Selectors, queries and policies use labels. An annotation holds other metadata: tool settings, URLs, notes. Use this rule from the [Helm best practices](https://helm.sh/docs/chart_best_practices/labels/). If no tool and no person selects or queries objects by a key, the key is an annotation.

| Need | Use |
| --- | --- |
| A selector, a network policy, a query, a report | A label |
| A setting for a controller, for example Argo CD sync options | An annotation |
| A URL, a contact, a long text, JSON | An annotation |

### Anatomy of a key

A key has an optional prefix and a name, with a `/` between them. The prefix is a DNS subdomain. Kubernetes reserves the prefixes `kubernetes.io/` and `k8s.io/` for its core components. A key without a prefix belongs to the user, but automated components must use a prefix ([Kubernetes: labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)).

```mermaid
flowchart LR
    key["tenant.infra.gsuquet.com/name"]
    key --> prefix["Prefix: tenant.infra.gsuquet.com<br/>DNS subdomain, max. 253 characters"]
    key --> slash["/"]
    key --> name["Name: name<br/>max. 63 characters"]
    prefix --> sub["Sub-group: tenant"]
    prefix --> group["Prefix of the repository: infra (one of the options)"]
    prefix --> domain["Domain of the owner: gsuquet.com"]
```

In text: the key `tenant.infra.gsuquet.com/name` has the prefix `tenant.infra.gsuquet.com` and the name `name`. The prefix has three parts: the sub-group `tenant`, the prefix of the repository `infra`, and the domain `gsuquet.com`. The example uses `infra` only to show the structure. Refer to [Q2](#q2-the-prefix-of-the-repository).

Many projects use sub-groups in the same way. Kubernetes has `node.kubernetes.io`, `topology.kubernetes.io` and `pod-security.kubernetes.io`. Argo CD has `link.argocd.argoproj.io`, `notice.argocd.argoproj.io` and `pref.argocd.argoproj.io` ([Argo CD: annotations and labels](https://argo-cd.readthedocs.io/en/stable/user-guide/annotations-and-labels/)). cert-manager has `acme.cert-manager.io` and `venafi.cert-manager.io` ([cert-manager: annotations](https://cert-manager.io/docs/reference/annotations/)).

### Families of keys

Each key in the repository belongs to one family. The family tells who owns the key.

| Family | Prefixes | Owner | The repository sets it |
| --- | --- | --- | --- |
| Kubernetes core | `kubernetes.io/`, `k8s.io/` and their subdomains, for example `pod-security.kubernetes.io/`, but not `app.kubernetes.io/` | Kubernetes | Only the keys that Kubernetes documents for users, for example the Pod Security labels |
| Recommended labels | `app.kubernetes.io/` | Shared convention | Yes, in the hand-written charts. The upstream charts set them too |
| Tools | `helm.sh/`, `argocd.argoproj.io/`, `cert-manager.io/`, `gateway.networking.k8s.io/` (a subdomain of `k8s.io`, but owned by the Gateway API project), Cilium keys | The tool | Only the documented settings, for example sync options |
| Repository | `<subgroup>.<prefix>.gsuquet.com/` | This repository | Yes. This RFC defines them |
| No prefix | None | The user | No. This RFC proposes to forbid new keys without a prefix |

### The custom prefix

The owner wants keys of the form `<subgroup>.<prefix>.gsuquet.com/<name>`. This follows the Kubernetes model. This RFC does not select `<prefix>`. [Q1](#q1-control-of-the-domain), [Q2](#q2-the-prefix-of-the-repository) and [Q3](#q3-rename-the-repository) give the options.

The repository already uses `infra.gsuquet.com` as an API group. The files `cluster.yaml`, `instance.yaml` and `module.yaml` have `apiVersion: infra.gsuquet.com/v1alpha1`, and the schemas in `schemas/` check this value. Projects often use the same domain for their API group and for their keys. Argo CD has the API group `argoproj.io` and the keys `argocd.argoproj.io/*`. cert-manager has the API group `cert-manager.io` and the keys `cert-manager.io/*`.

### Proposed sub-groups

Each sub-group has one subject. A key goes into a sub-group only when a tool, a policy or a report reads it. [Q4](#q4-the-sub-groups) asks which sub-groups to add first.

| Sub-group | Subject | Possible keys | Type | Reader |
| --- | --- | --- | --- | --- |
| `tenant` | The tenant that owns a namespace | `name` | Label, on `Namespace` only | Network policies, quotas, reports |
| `instance` | The instance that owns a cloud resource. The values come from `instance.yaml`. | `name`, `purpose`, `lifecycle`, `ttl`, `type` | Label, on cloud resources | Clean-up jobs, cost reports |
| `ownership` | The person or the team to contact | `owner` (label), `contact` (annotation) | Both | Persons, alerts |
| `network` | The trust zone and the exposure, for the zero-trust RFC | `zone`, `exposure` | Label, on `Namespace` only | `CiliumNetworkPolicy`, Conftest |
| `backup` | The backup policy of a volume or a namespace | `policy` (label), `retention` (annotation) | Both | The backup tool |
| `cost` | The cost center, for the cloud instances | `center` | Label | Cloud billing reports |

The sub-group names are singular nouns, as `node`, `topology` and `notice` in the examples above.

The `tenant` and `network` keys go only on a `Namespace`, never on a pod template. An application author controls the labels of the pods, thus a pod could select its own trust zone. The `Namespace` comes from `gitops/`, and Cilium reads its labels through `io.cilium.k8s.namespace.labels.*`. Check K4 refuses these keys on other kinds.

### Instance keys

`instances/<name>/instance.yaml` already holds the facts about an instance, and `schemas/instance.schema.json` checks them. The `instance` keys copy or derive these facts. They do not add new facts.

| Key | Source in `instance.yaml` | Values |
| --- | --- | --- |
| `instance.<p>/name` | `name` | DNS label, max. 40 characters, for example `kind-local` |
| `instance.<p>/purpose` | `purpose` | `production`, `test`, `demo` |
| `instance.<p>/lifecycle` | `lifecycle.type` | `long-lived`, `ephemeral` |
| `instance.<p>/ttl` | `lifecycle.ttl`, only for an ephemeral instance | For example `24h` or `7d` |
| `instance.<p>/type` | Derived from `layers`. Refer to the rule below. | The suffix of a `substrate-*` or `cluster-*` module in `modules/`, for example `kind` |

The rule for `instance.<p>/type`:

1. If `layers.substrate.modules` exists, the value is its first module name without `substrate-`. For example, `substrate-rpi` gives `rpi`.
2. Else, the value is the first module name of `layers.cluster.modules` without `cluster-`. For example, `cluster-kind` gives `kind` for `kind-local`.

Thus an instance with `substrate-rpi` and a Talos cluster module gets `rpi`, not `talos`. The value set is the set of `substrate-*` and `cluster-*` modules in `modules/`, thus a check can compute it. The key is `type`, not `substrate`, because `substrate` is already the name of a layer. [Q10](#q10-the-type-of-an-instance) gives the other options.

The `type` key answers the instance names question of RFC 0003 (PR #168). That question keeps the free instance names and gives "labels that hold the type" to this RFC. The two RFCs must keep the same answer.

This RFC proposes no end-date label. A clean-up job computes the end from `ttl` and the creation time of the cloud resource. A date that Terraform computes, for example with `timestamp()`, changes at each plan, unless a resource such as `time_static` of the `hashicorp/time` provider stores it.

The word "lifecycle" has one meaning only: the `lifecycle.type` of `instance.yaml`. Thus this RFC has no `lifecycle` sub-group.

### Required keys

This RFC proposes these required keys. [Q9](#q9-the-scope-of-the-required-keys) asks where the checks apply.

| Kind | Required labels | Required annotations |
| --- | --- | --- |
| `Namespace` in `gitops/` | `pod-security.kubernetes.io/enforce`, `audit` and `warn` (a check exists), `tenant.<p>/name`. The namespaces of the `infrastructure` components use the reserved value `platform`. The namespaces of the `apps` components use a tenant from `data.labels`, but not `platform`. | `argocd.argoproj.io/sync-wave: "-2"` (a check exists) |
| `CustomResourceDefinition` in `gitops/` | None | `argocd.argoproj.io/sync-wave: "-1"` (a check exists) |
| Pod template of a workload in a hand-written chart | `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/part-of` | None |
| Other objects of a hand-written chart | `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/managed-by` | None |
| Cloud resource that supports labels or tags | The cloud form of `instance.<p>/name`, `instance.<p>/purpose`, `instance.<p>/lifecycle` and `instance.<p>/type`. `instance.<p>/ttl` for an ephemeral instance. | Not applicable |

A Kubernetes object does not need the `instance` keys. Each cluster is one instance. The `tenant` keys go only on a `Namespace`, not on cloud resources.

`<p>` is the full prefix of the repository, for example `infra.gsuquet.com`.

## Detailed design

### Syntax rules

Kubernetes applies the same key rules to labels and to annotations ([labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/), [annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)).

| Part | Rule |
| --- | --- |
| Key prefix | Optional. A DNS subdomain: DNS labels with dots between them, max. 253 characters, then `/`. A DNS subdomain contains only lowercase letters, digits, `-` and `.`, and starts and ends with a letter or a digit ([Kubernetes: names](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/)). |
| Key name | Mandatory. Max. 63 characters. It starts and ends with a letter or a digit (`[a-z0-9A-Z]`). Between them: letters, digits, `-`, `_` and `.`. |
| Reserved prefixes | `kubernetes.io/` and `k8s.io/` are for the Kubernetes core components. |
| Label value | Max. 63 characters, or empty. If not empty, it starts and ends with a letter or a digit. Between them: letters, digits, `-`, `_` and `.`. |
| Annotation value | Any string. The total size of all the annotation keys and values on one object is max. 256 KiB. |
| Type | Keys and values are strings. Quote numbers and booleans in YAML, for example `"-2"` or `"true"`. |

This RFC adds rules for the keys of the repository:

- The key name uses lowercase letters, digits and `-` only. No `_` and no `.`. Thus the mapping to cloud keys in [Cloud labels and tags](#cloud-labels-and-tags) has no collision.
- The label values of the repository use lowercase letters, digits and `-` only. Thus the values are valid Google Cloud label values too.

### Recommended labels and Helm labels

Kubernetes recommends six labels with the shared prefix `app.kubernetes.io` ([Kubernetes: recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)). Helm recommends `helm.sh/chart` too ([Helm: labels and annotations](https://helm.sh/docs/chart_best_practices/labels/)).

| Key | Meaning | Example | Helm | Stable at an upgrade |
| --- | --- | --- | --- | --- |
| `app.kubernetes.io/name` | The name of the application | `argocd-server` | Recommended | Yes |
| `app.kubernetes.io/instance` | A unique name of the instance of the application. Helm uses the release name. | `argocd` | Recommended | Yes |
| `app.kubernetes.io/version` | The version of the application | `v3.5.6` | Optional | No |
| `app.kubernetes.io/component` | The component in the architecture | `server` | Optional | Yes |
| `app.kubernetes.io/part-of` | The higher-level application | `argocd` | Optional | Yes |
| `app.kubernetes.io/managed-by` | The tool that manages the operation of the application | `Helm` | Recommended | Yes |
| `helm.sh/chart` | The chart name and version: `{{ .Chart.Name }}-{{ .Chart.Version }}` | `argo-cd-10.11.6` | Recommended | No |

This repository uses the rendered manifests pattern. `mise run manifests:render` runs `helm template`, and Argo CD applies the output. Helm never runs in the cluster. Thus the rendered objects have `app.kubernetes.io/managed-by: Helm`, but Argo CD applies them. [Q5](#q5-the-value-of-appkubernetesiomanaged-by) asks which value to keep.

The selector of a `Deployment`, a `StatefulSet` or a `DaemonSet` is immutable. A selector must use only stable keys: `app.kubernetes.io/name` and `app.kubernetes.io/instance`. The upstream charts and the hand-written manifests already do this.

Helm also uses annotations: `helm.sh/hook`, `helm.sh/hook-weight`, `helm.sh/hook-delete-policy` and `helm.sh/resource-policy`. Argo CD maps the Helm hooks to its own hook phases, and `helm.sh/hook-weight` to `argocd.argoproj.io/sync-wave`. When an object has an Argo CD hook, Argo CD ignores all the Helm hooks ([Argo CD: Helm](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)).

### Argo CD keys

**Tracking.** Argo CD records the owner `Application` of each object. It has three tracking methods: `label`, `annotation` and `annotation+label`. The setting is `application.resourceTrackingMethod` in the `argocd-cm` ConfigMap ([Argo CD: resource tracking](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_tracking/)).

| Method | Key | Problem |
| --- | --- | --- |
| `label` | `app.kubernetes.io/instance`, or the key in `application.instanceLabelKey` | Max. 63 characters. Helm and operators also write `app.kubernetes.io/instance`, thus Argo CD can find the wrong owner. |
| `annotation` | `argocd.argoproj.io/tracking-id`, value `<app>:<group>/<kind>:<namespace>/<name>` | None of the label problems. |
| `annotation+label` | Both | The label is for information only. |

Since Argo CD 3.0, the default method is `annotation` ([Argo CD: upgrade from 2.14 to 3.0](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.14-3.0/)). The values in `gitops/infrastructure/argocd/sources/values.yaml` do not set the method, thus the new Argo CD uses the default. The legacy Argo CD (v3.3.7) in `kubernetes/bootstrap/argo-cd/` sets `application.instanceLabelKey: argocd.argoproj.io/instance`, but no method. The `label` and `annotation+label` methods use this key. [Q6](#q6-the-argo-cd-tracking-method) asks if the repository must set it explicitly.

**Sync options.** The annotation `argocd.argoproj.io/sync-options` holds a list of options with `,` between them, for example `Prune=false,Delete=false` ([Argo CD: sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)).

| Option | Effect | Use in the repository |
| --- | --- | --- |
| `Prune=false` | Argo CD does not prune the object. | The `argocd` Namespace, the Argo CD CRDs, `argocd-secret` |
| `Delete=false` | Argo CD keeps the object when it deletes the `Application`. | The `argocd` Namespace, `argocd-secret` |
| `Prune=confirm`, `Delete=confirm` | A person must confirm the prune or the delete. | None |
| `ServerSideApply=true` | Argo CD uses server-side apply for the object. | The Argo CD CRDs, and each `Application` at the `Application` level |
| `SkipDryRunOnMissingResource=true` | Argo CD skips the dry run when the CRD is not in the cluster yet. | None |
| `Replace=true`, `Force=true` | Argo CD replaces or deletes and creates the object again. These options can destroy data. | None. This RFC proposes to forbid them in hand-written objects and in the `Application` objects (check K10). |
| `PruneLast=true` | Argo CD prunes the object at the end of the sync. | None |
| `Validate=false` | Argo CD skips the validation of the object. | None |

**Sync waves and hooks.** The annotation `argocd.argoproj.io/sync-wave` holds an integer as a string. It can be negative. The default is `"0"`. Argo CD sorts by phase, then wave, then kind, then name ([Argo CD: sync waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)). The repository uses `"-2"` for a `Namespace`, `"-1"` for a CRD, `"0"` for the other objects and `"1"` or more for the `Application` objects. The annotation `argocd.argoproj.io/hook` holds the phase of a hook: `PreSync`, `Sync`, `Skip`, `PostSync`, `SyncFail`, `PreDelete` or `PostDelete`.

**Other Argo CD keys.** `argocd.argoproj.io/compare-options`, `argocd.argoproj.io/refresh`, `argocd.argoproj.io/skip-reconcile`, the `link.argocd.argoproj.io/*` and `notice.argocd.argoproj.io/*` annotations, and the label `argocd.argoproj.io/secret-type` on the repository and cluster Secrets.

### Cilium identity and stable labels

Cilium gives a security identity to each set of pods with the same identity-relevant labels. By default, all the labels of a pod are relevant, except a default list of exclusions ([Cilium: identity-relevant labels](https://docs.cilium.io/en/stable/operations/performance/scalability/identity-relevant-labels/)). The exclusions include `kubernetes.io`, `k8s.io`, `topology.kubernetes.io`, `pod-template-hash`, `controller-revision-hash` and `controller-uid`. The `labels` setting of the `cilium-config` ConfigMap, or the `labels` Helm value, adds patterns to the defaults. A pattern with `!` excludes keys. When the setting has one pattern without `!`, Cilium keeps only the matching keys and a default list: `reserved:.*`, `io.kubernetes.pod.namespace`, `io.cilium.k8s.namespace.labels`, `io.cilium.k8s.policy.cluster`, `io.cilium.k8s.policy.serviceaccount` and `app.kubernetes.io`.

A Cilium policy selects pods by their labels, by their namespace (`k8s:io.kubernetes.pod.namespace`), by the labels of their namespace (`io.cilium.k8s.namespace.labels.<key>`) and by their service account (`io.cilium.k8s.policy.serviceaccount`) ([Cilium: Kubernetes policies](https://docs.cilium.io/en/stable/security/policy/kubernetes/)).

The zero-trust RFC needs these facts:

| Label on a pod | Stable | Effect on Cilium |
| --- | --- | --- |
| `app.kubernetes.io/name`, `instance`, `component`, `part-of` | Yes | Good for policy selectors. |
| `app.kubernetes.io/version` | No. It changes at each upgrade. | A new identity at each upgrade. Do not select on it. |
| `helm.sh/chart` | No. It changes at each chart upgrade. | A new identity at each chart upgrade. Do not select on it. |
| `tenant.<p>/name`, `network.<p>/zone` | Yes | Not on pods. They go on the `Namespace`, and Cilium reads them through `io.cilium.k8s.namespace.labels.*`. |
| `pod-template-hash`, `controller-revision-hash` | No | Excluded by default. |

The rendered Argo CD pods carry `app.kubernetes.io/version` and `helm.sh/chart` in their pod template. The legacy manifests in `kubernetes/applications/` carry `app.kubernetes.io/version` in the pod template too. [Q7](#q7-volatile-labels-on-pod-templates) asks what to do.

If the zero-trust RFC adds an inclusive pattern to the Cilium `labels` setting, it must examine the namespace labels with the custom prefix. This RFC did not verify if the inclusive patterns filter `io.cilium.k8s.namespace.labels.*`.

Only the persons and the agents with write access to an object can change its labels. Thus a policy that trusts a label also trusts each identity that can change the label. Namespace labels are safer than pod labels, but not safe on their own. The `apps` AppProject can also create a `Namespace`. Refer to [Security considerations](#security-considerations).

### Node labels

The kubelet sets some labels on its own `Node` object. The NodeRestriction admission plugin lets a kubelet change these labels ([Kubernetes: admission controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)):

- `kubernetes.io/hostname`, `kubernetes.io/arch`, `kubernetes.io/os`.
- `beta.kubernetes.io/instance-type`, `node.kubernetes.io/instance-type`.
- `failure-domain.beta.kubernetes.io/region` and `failure-domain.beta.kubernetes.io/zone` (deprecated), `topology.kubernetes.io/region`, `topology.kubernetes.io/zone`.
- The keys with the prefix `kubelet.kubernetes.io/` or `node.kubernetes.io/`.

The plugin forbids two prefixes to kubelets. `node-restriction.kubernetes.io/` is for administrators, to label nodes for workload isolation. `node-role.kubernetes.io/` stops a node from declaring its own cluster role. The plugin also disallows most other keys under `kubernetes.io` and `k8s.io`.

Thus a node label for isolation, for example the nodes that can run the internet-facing pods, uses `node-restriction.kubernetes.io/`, not the custom prefix. The node configuration cannot set it. The Talos `machine.nodeLabels` documentation tells that worker nodes cannot set labels with some prefixes, because of NodeRestriction ([Talos configuration](https://docs.siderolabs.com/talos/v1.11/reference/configuration/v1alpha1/config)). An administrator identity sets these labels after the node joins, for example `kubectl` or the Terraform `kubernetes` provider. This RFC did not verify the behavior of Kind.

### Other keys of the stack

| Key | Type | Owner | Use |
| --- | --- | --- | --- |
| `pod-security.kubernetes.io/enforce`, `audit`, `warn` | Label on `Namespace` | Kubernetes | Pod Security level: `privileged`, `baseline` or `restricted`. A check exists. |
| `pod-security.kubernetes.io/enforce-version`, `audit-version`, `warn-version` | Label on `Namespace` | Kubernetes | The version of the Pod Security Standards: `latest` or a Kubernetes minor version. Not used. |
| `kubernetes.io/metadata.name` | Label on `Namespace` | Kubernetes | The API server sets it to the name of the namespace. Network policies select namespaces with it. |
| `kubernetes.io/os` | Node label, used in `nodeSelector` | Kubernetes | The upstream charts select `linux` nodes. |
| `kubectl.kubernetes.io/default-container` | Annotation on a pod | kubectl | The default container for `kubectl logs` and `kubectl exec`. |
| `cert-manager.io/cluster-issuer`, `cert-manager.io/issuer` | Annotation on `Gateway` or `Ingress` | cert-manager | The issuer of the certificate. Refer to [cert-manager: annotations](https://cert-manager.io/docs/reference/annotations/). |
| `gateway.networking.k8s.io/bundle-version`, `gateway.networking.k8s.io/channel` | Annotation on the Gateway API CRDs | Gateway API | The version and the release channel of the CRD bundle. The [CRD management guide](https://gateway-api.sigs.k8s.io/guides/crd-management/) tells why to use the standard channel. |
| `gateway.networking.k8s.io/policy` | Annotation on the Gateway API policy CRDs | Gateway API | The value in the repository is `Direct`. Information only. |
| `controller-gen.kubebuilder.io/version` | Annotation on CRDs | Kubebuilder | Information only. |
| `io.cilium/app` | Label on Cilium pods | Cilium | Used in the anti-affinity of the Cilium operator. |

### Cloud labels and tags

Google Cloud labels and Azure tags have rules that are different from Kubernetes labels.

| Rule | Kubernetes label | Google Cloud label | Azure tag |
| --- | --- | --- | --- |
| Max. count on one resource | No limit in the label documentation | 64 | 50 (15 on some resource types) |
| Key length | Prefix 253, name 63 | 1 to 63 | 512 (128 on storage accounts) |
| Key characters | Letters, digits, `-`, `_`, `.`, one `/` | Lowercase letters, digits, `_`, `-`, international characters | All except `<`, `>`, `%`, `&`, `\`, `?`, `/` |
| Key start | Letter or digit | Lowercase letter or international character | Some types refuse a digit, for example Azure DNS and Traffic Manager |
| Case | Keys and values are case-sensitive | Lowercase only | Names are not case-sensitive in operations, values are case-sensitive |
| Value length | 63, can be empty | 63, can be empty | 256 |
| Value characters | Letters, digits, `-`, `_`, `.` | Lowercase letters, digits, `_`, `-`, international characters | All |
| Sensitive data | Not for secrets | Do not put sensitive data | Tags are plain text. Do not put sensitive values. |

Sources: [Google Cloud: labels](https://docs.cloud.google.com/resource-manager/docs/labels-overview), [Azure: tags](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources). The Google Cloud page does not list `/` or `.` as permitted characters. Azure forbids `/` in tag names, and Azure Front Door and Traffic Manager refuse `:` and `#`. Azure DNS tag names do not support "special and Unicode characters". The page does not tell if `_` and `-` are special characters. Azure Automation, Azure Content Delivery Network, Azure public and private DNS (zones and A records) and Log Analytics saved searches accept only 15 tags.

Google Cloud also has Resource Manager tags. Tags can set conditions on IAM policies, and labels cannot. This RFC covers only labels.

**Terraform mechanisms.**

| Provider | Mechanism | Notes |
| --- | --- | --- |
| `hashicorp/google` | `default_labels` in the `provider` block | Applies to each resource with a top-level `labels` field, or a `labels` field in a top-level `metadata` field. A label on the resource overrides the default. The plan shows them in `terraform_labels` and `effective_labels`. The provider also adds `goog-terraform-provisioned = true` by default (`add_terraform_attribution_label`). Source: [provider reference](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference). |
| `hashicorp/azurerm` | None at the provider level | The [provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) of version 5.12.0 has no default tags. Each module takes a `tags` variable and gives it to each resource. Resources do not get the tags of their resource group. Azure Policy can copy them. |
| `hashicorp/kubernetes` | None | The provider has `ignore_labels` and `ignore_annotations` to ignore keys that other tools add ([provider documentation](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)). The modules `bootstrap-cilium` and `bootstrap-cert-manager` have a `common_labels` variable for the chart values. |

On GKE, two sets of labels exist, and they do not share labels ([GKE: cluster labels](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/creating-managing-labels)). The Google Cloud labels of the cluster and the node pools go on the cloud resources. The Kubernetes labels of a node pool go on the `Node` objects. This RFC applies the Kubernetes rules to the second set.

- GKE copies the cluster labels to the nodes, the Compute Engine instances and the attached persistent disks. A background process does this once each hour, thus a label can arrive up to one hour after the VM. A clean-up job must allow for this delay on new VMs. GKE does not copy the labels to load balancer rules, IP addresses or disks that are not attached. Node pool labels override the cluster labels.
- The `google_container_cluster` resource puts the provider `default_labels` in `terraform_labels`, with its `resource_labels`. Thus the defaults reach the cluster labels.
- `node_config.resource_labels` is a nested field. The provider documentation shows no `terraform_labels` for it, thus the provider `default_labels` do not reach it. Node pool labels are optional: the cluster labels reach the nodes too. A module sets them only to override a cluster label, or to stop the delay of up to one hour. The implementation PR verifies this with a plan.

**Mapping.** This RFC proposes one mechanical rule from a Kubernetes key to a cloud key. [Q8](#q8-the-mapping-to-cloud-keys) gives the other options.

1. Change each `.` and `/` to `_`.
2. Change all letters to lowercase.
3. The result must have max. 63 characters. A Conftest check refuses a longer key.
4. The value stays the same. The value rules of the repository already give valid Google Cloud values. Check K13 refuses a value that is not valid, for example `2.0.22`. Thus a key such as `app.kubernetes.io/version` does not go in the map of cloud labels.

```mermaid
flowchart LR
    k8s["Key<br/>instance.infra.gsuquet.com/name"] --> rule["Change . and / to _<br/>Lowercase<br/>Max. 63 characters"]
    rule --> gcp["Google Cloud label key<br/>instance_infra_gsuquet_com_name"]
    rule --> az["Azure tag name<br/>instance_infra_gsuquet_com_name"]
    yaml["instance.yaml"] --> tf["Terraform: local.cloud_labels"]
    tf --> gdl["google: default_labels"]
    tf --> azt["azurerm: tags variable of each module"]
```

In text: the rule changes `instance.infra.gsuquet.com/name` to `instance_infra_gsuquet_com_name`. Google Cloud and Azure use the same key. Each instance builds one map of cloud labels from `instance.yaml`. Terraform gives it to `default_labels` on Google Cloud and to the `tags` variables on Azure. This map does not go to the Kubernetes objects. The Kubernetes labels come from the chart sources in `gitops/`.

The root module of an instance builds the map in a local value, for example `local.cloud_labels`, from `yamldecode(file("${path.module}/instance.yaml"))`. Thus the values have one source, and `schemas:check` already validates that source.

| Kubernetes key | Cloud key |
| --- | --- |
| `app.kubernetes.io/part-of` | `app_kubernetes_io_part-of` |
| `instance.<p>/name` | `instance_<p>_name`, for example `instance_infra_gsuquet_com_name` |
| `instance.<p>/purpose` | `instance_<p>_purpose` |
| `cost.<p>/center` | `cost_<p>_center` |

The rule can give the same cloud key for two keys of other tools, for example `foo.io/bar_baz` and `foo.io.bar/baz`. The keys of the repository have no `_`, no `.` and no uppercase letter in the name, thus they do not collide with each other or with `app.kubernetes.io/*`. Check K13 refuses two keys with the same cloud form in one map.

### Enforcement

Rule 8 of `AGENTS.md` asks for a check for each rule. This RFC describes the checks. It does not implement them. All the checks go in `policy/kubernetes/kubernetes.rego` and `policy/terraform/terraform.rego`, with a test for each case that must pass and each case that must fail. Conftest supports `deny` rules, which fail the check, and `warn` rules, which do not fail it ([Conftest](https://www.conftest.dev/)).

A data file, for example `policy/data/labels.yaml`, holds the reference table: the sub-groups, the keys, their type, their kinds and their permitted values. It also holds the allowlists of K2, K3 and K14. `conftest --data` loads it, and the policies read it as `data.labels`. Thus the table and the checks have one source. Today `.mise/tasks/lint/policy.sh` gives no `--data` option to Conftest. The implementation PR adds it.

**Input of the checks.** `.mise/tasks/lint/policy.sh` runs the `kubernetes` namespace on `kubernetes/*.yaml` and `gitops/*.yaml`, but not on `gitops/*/sources/templates/*`, because Helm templates are not YAML before they render. Thus the objects of the hand-written charts of `gitops/` exist only in `rendered/<component>/`. The checks find the origin of a rendered object in this way:

1. The path `gitops/clusters/<cluster>/rendered/<component>/` gives the component. `gitops/clusters/<cluster>/cluster.yaml` tells if the component is in `infrastructure` or in `apps`.
2. The file name tells if the object comes from an upstream chart. This needs a change of `.mise/tasks/manifests/render.sh`, which the implementation PR makes. This RFC does not implement it.

A label cannot give the origin. The three Argo CD CRDs come from the upstream chart, but they have no `helm.sh/chart` label. The objects of a subchart carry the name of the subchart. A hand-written template can also set `helm.sh/chart` to the value of a dependency, and then skip the checks. The only reliable marker is the `# Source:` comment that `helm template` writes, for example `# Source: argocd/charts/argo-cd/templates/crds/crd-application.yaml`. Conftest drops comments, and `split_manifest_by_resource` in `render.sh` names each file `<kind>-<name>.yaml`.

The proposed change: `render.sh` reads the `# Source:` comment of each object. If the source path contains `/charts/`, the object comes from a dependency, and the file name gets the prefix `upstream--`, for example `upstream--customresourcedefinition-applications.argoproj.io.yaml`. The checks then read the origin from `file.path`. The files stay in one folder. A subfolder such as `rendered/<component>/upstream/` also works, but the `Application` must then set `directory.recurse: true`. A local subchart in `sources/charts/` also counts as upstream, thus a review must refuse local subcharts that hold hand-written objects.

The implementation PR verifies the rule on the `argocd` component. The checks K2 to K6 and K10 apply to the hand-written objects. The legacy files in `kubernetes/` get only K1, because the migration removes them.

The checks read the keys in `metadata.labels` and `metadata.annotations`, also in pod templates. They do not read the keys in selectors, for example `nodeSelector` or `namespaceSelector`. Thus `kubernetes.io/os` in a `nodeSelector` is not a K2 problem.

| Check | Input | Rule | Level |
| --- | --- | --- | --- |
| K1 Syntax | Each object in `gitops/` and `kubernetes/` | Each label key, label value and annotation key matches the syntax rules. `regex.match` checks the patterns ([OPA: regex](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex)). | `deny` |
| K2 Reserved prefixes | Hand-written objects in `gitops/` | No key with the prefix `kubernetes.io/`, `k8s.io/` or one of their subdomains, except the allowlist in `data.labels`: `app.kubernetes.io/`, the Pod Security labels, `kubernetes.io/metadata.name`, `kubernetes.io/os`, `kubectl.kubernetes.io/default-container`, `node-restriction.kubernetes.io/` and `gateway.networking.k8s.io/`. The last entry is for hand-written Gateway API objects. | `deny` |
| K3 No prefix | Hand-written objects in `gitops/` | No key without a prefix, except the allowlist in `data.labels`. Conftest has no earlier state to compare with, thus the check refuses all keys without a prefix, not only new keys. | `deny` |
| K3w No prefix in upstream charts | Upstream objects in `gitops/` | The same rule as K3. | `warn` |
| K4 Custom keys | All objects in `gitops/` | Each key with the custom prefix uses a sub-group and a name from `data.labels`, on a permitted kind, with a permitted value. The `tenant` and `network` keys are only permitted on a `Namespace`. | `deny` |
| K5 Required keys | `Namespace` objects in `gitops/` | The required labels of the table in [Required keys](#required-keys). `tenant.<p>/name` is `platform` for an `infrastructure` component, and a tenant of `data.labels` other than `platform` for an `apps` component. | `deny` |
| K6 Required keys of workloads | Pod templates and objects of the hand-written objects in `gitops/` | The required `app.kubernetes.io/*` labels. | `deny` |
| K7 Required keys in upstream charts | Rendered upstream objects | The same keys as K6. Upstream charts do not always let the repository set them. | `warn` |
| K8 Stable selectors | `spec.selector.matchLabels` of workloads, and `spec.selector` of a `Service` | No `app.kubernetes.io/version` and no `helm.sh/chart`. | `deny` |
| K9 Argo CD tracking | The rendered `argocd-cm` ConfigMap | `application.resourceTrackingMethod` is `annotation`, if the owner selects this in Q6. | `deny` |
| K10 Sync options | Hand-written objects and `Application` objects in `gitops/` | No `Replace=true` and no `Force=true`, in the annotation `argocd.argoproj.io/sync-options` and in `spec.syncPolicy.syncOptions` of an `Application`. | `deny` |
| K11 Cloud defaults | `provider "google"` blocks and module calls in `instances/` | `default_labels` and each `tags` argument of a module call reference `local.cloud_labels`. The `hcl2` parser gives the expression as a string, for example `${local.cloud_labels}`. The Terraform run of Conftest does not read `instance.yaml`. Thus `.mise/tasks/_base/instance-checks.sh`, which `schemas:check` runs, checks the values of the map against `instance.yaml`. | `deny` |
| K12 Cloud tags | `azurerm` resources in `modules/` with a `tags` argument | The argument comes from the `tags` variable of the module. Azure DNS resources can need an exemption. Refer to [Rollout](#rollout). | `deny` |
| K13 Cloud keys | Keys and values of `default_labels` and `tags` | The cloud form of each key has max. 63 characters. Each value is a valid Google Cloud value. No two keys in one map have the same cloud form. | `deny` |
| K14 Pod Security of applications | `Namespace` objects of the components in `apps` | `pod-security.kubernetes.io/enforce` is `restricted` or `baseline`, except for the namespaces in the allowlist of `data.labels`. | `deny` |
| K15 Namespace of a component | `Namespace` objects in `gitops/clusters/<cluster>/rendered/<component>/` | `metadata.name` is equal to the `namespace` of the component in `cluster.yaml`. | `deny` |

The existing checks stay: the Pod Security labels on a `Namespace`, the sync waves, no `CreateNamespace=true` in an `Application`, and no `resources-finalizer.argocd.argoproj.io` finalizer.

### Inventory of the keys in use

The inventory comes from `main` at commit `76b6fa0`, from `gitops/`, `modules/`, `instances/` and `kubernetes/`.

| Key | Where | Set by |
| --- | --- | --- |
| `app.kubernetes.io/name`, `instance`, `version`, `component`, `part-of`, `managed-by` | Rendered Argo CD objects in `gitops/clusters/kind-local/rendered/argocd/`, chart sources in `modules/`, legacy manifests in `kubernetes/` | Upstream charts. The legacy manifests set them by hand, with `managed-by: argocd`. |
| `helm.sh/chart` | Rendered Argo CD objects, also in pod templates | Upstream charts |
| `helm.sh/hook`, `helm.sh/hook-weight`, `helm.sh/hook-delete-policy` | The Argo CD Redis secret job, the module charts | Upstream charts |
| `helm.sh/resource-policy: keep` | The three Argo CD CRDs | Upstream chart |
| `argocd.argoproj.io/sync-wave` | The `argocd` Namespace, the Argo CD CRDs, each `Application` | `gitops/infrastructure/argocd/sources/` |
| `argocd.argoproj.io/sync-options` | The `argocd` Namespace and `argocd-secret` (`Prune=false,Delete=false`), the Argo CD CRDs (`ServerSideApply=true,Prune=false`) | `gitops/infrastructure/argocd/sources/` |
| `pod-security.kubernetes.io/enforce`, `audit`, `warn` | The `argocd` Namespace, all `restricted` | `gitops/infrastructure/argocd/sources/templates/namespace.yaml` |
| `kubernetes.io/os` | `nodeSelector` of upstream workloads | Upstream charts |
| `gateway.networking.k8s.io/bundle-version`, `channel`, `policy` | Gateway API CRDs in `modules/bootstrap-gateway-api/manifests/` | Upstream bundle |
| `controller-gen.kubebuilder.io/version` | Agent sandbox CRDs | Upstream chart |
| `io.cilium/app` | Cilium operator anti-affinity | Cilium values |
| `checksum/*` | Pod template annotations of Argo CD | Upstream chart |
| `common_labels` (Terraform variable) | `modules/bootstrap-cilium`, `modules/bootstrap-cert-manager` | Default `{}`. `instances/kind-local` does not set it. |
| `application.instanceLabelKey: argocd.argoproj.io/instance` (setting, not a key on an object) | `kubernetes/bootstrap/argo-cd/manifests/argocd-configs-argocd-cm.yaml`, the legacy Argo CD v3.3.7 of the production cluster | The legacy chart values. No `application.resourceTrackingMethod`. |
| `infra.gsuquet.com/v1alpha1` (API group, not a key) | `cluster.yaml`, `instance.yaml`, `module.yaml` and `schemas/` | The repository |

No cloud provider exists in the code yet. No `default_labels` and no `tags` exist. No key uses a custom prefix. Neither Argo CD sets `application.resourceTrackingMethod`. Thus both use the default `annotation` method of Argo CD 3, and write `argocd.argoproj.io/tracking-id` in the cluster.

### Reference table

This table is the draft of a future reference page, `docs/reference/labels-and-annotations.md`. `<p>` is the prefix of the repository. The custom keys stay proposals until the owner answers the unresolved questions.

| Key | Type | Kinds | Values | Set by | Required | Stable |
| --- | --- | --- | --- | --- | --- | --- |
| `app.kubernetes.io/name` | Label | All | Name of the application | Chart | Yes | Yes |
| `app.kubernetes.io/instance` | Label | All | Release name | Chart | Yes | Yes |
| `app.kubernetes.io/part-of` | Label | All | Higher-level application | Chart | Pod templates | Yes |
| `app.kubernetes.io/component` | Label | All | Role in the architecture | Chart | No | Yes |
| `app.kubernetes.io/managed-by` | Label | All | Refer to Q5 | Chart | Yes | Yes |
| `app.kubernetes.io/version` | Label | All | Version of the application | Chart | No | No |
| `helm.sh/chart` | Label | All | `<chart>-<version>` | Chart | No | No |
| `pod-security.kubernetes.io/enforce`, `audit`, `warn` | Label | `Namespace` | `privileged`, `baseline`, `restricted` | Repository | Yes | Yes |
| `node-restriction.kubernetes.io/<name>` | Label | `Node` | Lowercase, digits, `-` | An administrator, after the node joins | No | Yes |
| `tenant.<p>/name` | Label | `Namespace` | A tenant of `data.labels`. `platform` for the `infrastructure` components. | Repository | Yes | Yes |
| `ownership.<p>/owner` | Label | `Namespace` | Owner name | Repository | No | Yes |
| `ownership.<p>/contact` | Annotation | `Namespace` | URL or address | Repository | No | Not applicable |
| `network.<p>/zone` | Label | `Namespace` | Refer to the zero-trust RFC | Repository | No | Yes |
| `network.<p>/exposure` | Label | `Namespace` | Refer to the zero-trust RFC | Repository | No | Yes |
| `backup.<p>/policy` | Label | `Namespace`, `PersistentVolumeClaim` | Refer to a later backup RFC | Repository | No | Yes |
| `backup.<p>/retention` | Annotation | `Namespace`, `PersistentVolumeClaim` | Refer to a later backup RFC | Repository | No | Not applicable |
| `cost.<p>/center` | Label | Cloud resources, `Namespace` | Lowercase, digits, `-` | Instance | No | Yes |
| `instance.<p>/name` | Label | Cloud resources | `name` of `instance.yaml` | Instance | Yes | Yes |
| `instance.<p>/purpose` | Label | Cloud resources | `production`, `test`, `demo` | Instance | Yes | Yes |
| `instance.<p>/lifecycle` | Label | Cloud resources | `long-lived`, `ephemeral` | Instance | Yes | Yes |
| `instance.<p>/ttl` | Label | Cloud resources | For example `24h`, `7d` | Instance | Ephemeral instances | Yes |
| `instance.<p>/type` | Label | Cloud resources | Derived from `layers` of `instance.yaml`, for example `kind`, `rpi` | Instance | Yes | Yes |
| `argocd.argoproj.io/sync-wave` | Annotation | All | Integer as a string | Repository | `Namespace`, CRD | Not applicable |
| `argocd.argoproj.io/sync-options` | Annotation | All | Options with `,` between them | Repository | No | Not applicable |
| `argocd.argoproj.io/tracking-id` | Annotation | All | `<app>:<group>/<kind>:<namespace>/<name>` | Argo CD | Not applicable | Not applicable |
| `helm.sh/hook`, `helm.sh/hook-weight`, `helm.sh/hook-delete-policy` | Annotation | Hook objects | Helm values | Chart | No | Not applicable |
| `cert-manager.io/cluster-issuer` | Annotation | `Gateway` | Name of a `ClusterIssuer` | Repository | No | Not applicable |

## Security considerations

- Labels, annotations, cloud labels and cloud tags are plain text. Persons with read access, cost reports and logs can see them. They must not hold secrets, credentials or personal data. Google Cloud and Azure give the same warning.
- A network policy that selects pods by a label trusts each identity that can change the label. The `apps` AppProject has `clusterResourceWhitelist: [{group: "", kind: Namespace}]` in `gitops/infrastructure/argocd/sources/templates/appproject-apps.yaml`. Thus an application component can create a `Namespace` with any name and any labels:
  - It can set `tenant` and `network` labels, and select its own trust zone.
  - It can set `pod-security.kubernetes.io/enforce: privileged`. The current Pod Security rule in `policy/kubernetes/kubernetes.rego` accepts all three levels. Thus the namespace can run privileged pods.
- The `sourceRepos` of the `apps` AppProject is only this repository. Thus the trust boundary is the review of each PR that changes `gitops/apps/`, and the merge of the owner. This RFC proposes four more controls:
  - Check K14: the namespaces of `apps` components use `restricted` or `baseline`, except an allowlist.
  - Check K4, with the permitted values of the `tenant` and `network` keys for each component in `data.labels`.
  - The sync option `FailOnSharedResource=true` on each `Application`. Argo CD then fails a sync when another `Application` already applied the same object ([Argo CD: sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)). Thus an `apps` component cannot take over a `Namespace` that another `Application` manages. It does not protect the namespaces that no `Application` manages, for example `default`, `kube-system` or the namespaces that Terraform creates.
  - Check K15: a `Namespace` in `rendered/<component>/` has the name of the `namespace` of that component in `cluster.yaml`. Thus a component cannot apply a `Namespace` with another name.
- The [Argo CD projects page](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/) shows a `clusterResourceWhitelist` entry for `Namespace` objects with a name pattern. The zero-trust RFC can use it. This RFC did not verify if Argo CD applies the destination rules `!argocd` and `!kube-system` to a `Namespace` object, which is cluster-scoped.
- A node label for isolation must use `node-restriction.kubernetes.io/`. A kubelet cannot change this prefix. Thus a compromised node cannot attract the pods of another trust zone with this label. An administrator identity sets the label, not the node configuration.
- The custom prefix uses a domain. If the owner does not control the domain, another party can use the same keys with a different meaning. Refer to Q1.
- The Argo CD `annotation` tracking method stops a chart or an operator from changing the owner of an object through `app.kubernetes.io/instance`. Thus Argo CD does not prune objects of another tool by mistake.
- The sync options `Replace=true` and `Force=true` can delete objects and their data. Check K10 forbids them in hand-written objects and in `Application` objects.

## Rollout

1. The owner answers the unresolved questions in this PR. When the owner asks, the author sets the final status, and the owner merges this PR.
2. The author derives the ADRs in a new PR. Possible ADRs:
   - "Use the custom prefix `<subgroup>.<prefix>.gsuquet.com`".
   - "Use the required keys and the sub-groups of the reference table".
   - "Use the `annotation` tracking method of Argo CD".
   - "Map Kubernetes keys to cloud labels and tags with one rule".
3. In a separate PR, an author adds `policy/data/labels.yaml` and the `--data policy/data` option in `.mise/tasks/lint/policy.sh`. The same PR changes `render.sh` for the `upstream--` prefix, and adds the checks K1 to K10, K14 and K15, with tests. The checks start as `warn` for one PR if the existing files fail them. Then they change to `deny`.
4. An author adds the reference page `docs/reference/labels-and-annotations.md` from the reference table, and updates `docs/reference/policies.md`.
5. An author adds the required labels to the `argocd` Namespace and to the later components, through the chart sources and `mise run manifests:render`.
6. The checks K11 to K13 come with the first GKE or Azure instance. Before the ADR for Azure, an author tests a tag name with `_` and `-` on an Azure DNS zone. If Azure refuses it, K12 and K13 exempt the Azure DNS resources.
7. The legacy manifests in `kubernetes/` do not change. The migration removes them.

To go back, revert the PRs of steps 3 to 5. Labels and annotations do not change the behavior of the workloads, except for the Argo CD tracking method and the Cilium policies. After a change of the tracking method, Argo CD writes new tracking keys at the next sync. Refer to the [Argo CD 3.0 upgrade notes](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.14-3.0/).

## Drawbacks

- The required keys add lines to each `Namespace` and each hand-written chart.
- The custom prefix is long. A key such as `instance.infra.gsuquet.com/purpose` has 34 characters.
- The cloud keys are long and not easy to read, for example `tenant_infra_gsuquet_com_name`.
- The upstream charts do not always let the repository add labels to all their objects. Thus check K7 is only a warning.
- A data file and its checks are more code to maintain.

## Rationale and alternatives

- **No custom prefix, keys without a prefix.** Kubernetes lets users do this, but each automated tool must use a prefix. Agents and Argo CD are tools of this type. Keys without a prefix can collide with the keys of upstream charts, for example `app` or `component`.
- **One flat prefix, for example `infra.gsuquet.com/tenant`.** It is shorter. But each new subject adds names to one flat list, and a selector cannot match one subject by its prefix. The sub-groups follow Kubernetes and Argo CD.
- **Only the recommended labels.** `app.kubernetes.io/*` has no key for a tenant, a trust zone or an instance.
- **Annotations for the tenant and the zone.** Selectors and Cilium policies cannot select by annotations.
- **One cloud key form for each cloud.** Azure accepts `.` in tag names, thus it can keep more of the Kubernetes key. But two forms need two checks, and a query that covers both clouds needs two keys. Refer to Q8.
- **No rules.** Each chart and each agent continues to use different keys. The zero-trust RFC then has no stable base.

## Prior art

- **Kubernetes.** The [labels and selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/) and [annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/) pages give the syntax rules. [Recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/) gives the `app.kubernetes.io` labels. [Well-known labels, annotations and taints](https://kubernetes.io/docs/reference/labels-annotations-taints/) lists the core keys, with sub-groups such as `node.kubernetes.io`, `topology.kubernetes.io` and `pod-security.kubernetes.io`. [Object names](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/) defines a DNS subdomain. The [NodeRestriction](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) plugin reserves `node-restriction.kubernetes.io/` for administrators, and forbids `node-role.kubernetes.io/` to kubelets.
- **Helm.** [Labels and annotations](https://helm.sh/docs/chart_best_practices/labels/) gives the standard labels, and the rule: a key that nobody queries is an annotation.
- **Talos.** The [configuration reference](https://docs.siderolabs.com/talos/v1.11/reference/configuration/v1alpha1/config) tells that NodeRestriction limits the `machine.nodeLabels` of worker nodes.
- **Argo CD.** [Resource tracking](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_tracking/) compares the tracking methods. [Annotations and labels](https://argo-cd.readthedocs.io/en/stable/user-guide/annotations-and-labels/) lists the keys, with the sub-groups `link`, `notice` and `pref`. [Sync options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/), [sync waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/) and [Helm](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/) give the behavior of the annotations. The [3.0 upgrade notes](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.14-3.0/) change the default tracking method to `annotation`. [Projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/) gives the rules for cluster-scoped objects.
- **Cilium.** [Identity-relevant labels](https://docs.cilium.io/en/stable/operations/performance/scalability/identity-relevant-labels/) tells how labels give identities, and warns that labels with hashes or timestamps give one identity for each pod. [Kubernetes policies](https://docs.cilium.io/en/stable/security/policy/kubernetes/) gives the namespace and service account selectors.
- **cert-manager.** [Annotations](https://cert-manager.io/docs/reference/annotations/) uses the sub-groups `acme`, `experimental` and `venafi`.
- **Gateway API.** The [CRD management guide](https://gateway-api.sigs.k8s.io/guides/crd-management/) explains the release channels.
- **Google Cloud.** [Labels overview](https://docs.cloud.google.com/resource-manager/docs/labels-overview) gives the label rules and the difference from tags. [GKE cluster labels](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/creating-managing-labels) tells how GKE copies the labels to the nodes and the disks.
- **Azure.** [Use tags](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources) gives the tag rules.
- **Terraform.** The [Google provider reference](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference) gives `default_labels` and the attribution label. The [`google_container_cluster`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) page gives `resource_labels`, `terraform_labels` and `node_config.resource_labels`. The [AzureRM provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) and the [Kubernetes provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs) have no default labels or tags.
- **GitHub.** [Renaming a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository) tells what GitHub redirects after a rename.
- **Conftest and OPA.** [Conftest](https://www.conftest.dev/) runs the policies. [OPA regex built-ins](https://www.openpolicyagent.org/docs/policy-reference/builtins/regex) give `regex.match`.

## Unresolved questions

### Q1: Control of the domain

A prefix must be a domain that the owner controls. Else another party can use the same keys. The API group `infra.gsuquet.com` has the same need.

- **A.** The owner controls `gsuquet.com`. Use it.
- **B.** The owner does not control `gsuquet.com`, but can register it. Register it before the ADR.
- **C.** The owner controls a different domain. Use that domain, and change the API group in `schemas/` too.
- **D.** Use `gsuquet.github.io`. GitHub gives this domain to the account `gsuquet`. But GitHub controls it, and it can change with the account name.

Recommendation: A, if the owner controls the domain. Else B. The owner must answer before Q2.

### Q2: The prefix of the repository

The form is `<subgroup>.<prefix>.gsuquet.com/<name>`.

| Option | Example key | For | Against |
| --- | --- | --- | --- |
| **A.** `homelab.gsuquet.com` | `tenant.homelab.gsuquet.com/name` | Same name as the repository. | The repository also holds GKE and Azure instances, which are not a homelab. Different from the API group. |
| **B.** `infra.gsuquet.com` | `tenant.infra.gsuquet.com/name` | Same as the existing API group `infra.gsuquet.com`. Covers all the instances. | Different from the name of the repository. |
| **C.** `gsuquet.com` (no middle part) | `tenant.gsuquet.com/name` | Shortest keys. | Other projects of the owner can use the same domain with a different meaning. |
| **D.** `platform.gsuquet.com` | `tenant.platform.gsuquet.com/name` | Fits a later internal developer platform, for example OpenChoreo. | A new name. Different from the API group and the repository. |

Recommendation: B. It has one domain for the API group and the keys, as Argo CD and cert-manager do.

### Q3: Rename the repository

The owner asked if the repository name must match the prefix.

- **A.** Keep `homelab`. No work. The prefix and the name stay different, if the owner selects B, C or D in Q2.
- **B.** Rename the repository to match the prefix, for example `infra`. GitHub redirects the web pages and the Git operations. But GitHub does not redirect calls to actions in a renamed repository, and the old name must stay free. The rename also changes `gitops.repoURL`, the Argo CD repository settings, the badges and the links in `docs/`.
- **C.** Decide in RFC 0003, which covers the structure of the repository.

Recommendation: C. The name of the repository is a subject of RFC 0003. Labels do not need the same name.

### Q4: The sub-groups

- **A.** Add all six sub-groups now: `tenant`, `instance`, `ownership`, `network`, `backup`, `cost`.
- **B.** Add only the sub-groups with a reader now: `tenant` and `instance`. Reserve `network` for the zero-trust RFC, `backup` for a backup RFC and `cost` for the first cloud instance. Remove `ownership`, until a later RFC adds a second person or team. RFC 0002 has no Kubernetes key for ownership.
- **C.** A different list.

Recommendation: B. A key without a reader has no check that proves its use.

### Q5: The value of `app.kubernetes.io/managed-by`

The rendered objects have `Helm`, because `helm template` makes them. Argo CD applies them. The legacy manifests have `argocd`.

- **A.** Keep the value of the chart (`Helm`). The label tells which tool makes the manifest. The tracking annotation tells which `Application` applies it.
- **B.** Set `argocd` on all objects. The upstream charts do not always let the repository change this label.
- **C.** Remove the label from the hand-written charts.

Recommendation: A. It needs no change of upstream charts, and the tracking annotation already tells the owner.

### Q6: The Argo CD tracking method

- **A.** Keep the default. Argo CD 3.0 and later use `annotation`.
- **B.** Set `application.resourceTrackingMethod: annotation` explicitly in the values, and add check K9.
- **C.** Use `annotation+label`, to see the owner in label queries.

Recommendation: B. An explicit value stays the same if a later version changes the default, and a check can test it.

### Q7: Volatile labels on pod templates

`app.kubernetes.io/version` and `helm.sh/chart` change at each upgrade. On a pod template, they give a new Cilium identity at each upgrade.

- **A.** Do nothing now. The zero-trust RFC decides.
- **B.** Add exclusive patterns to the Cilium `labels` setting now, for example `!app\.kubernetes\.io/version` and `!helm\.sh/chart`.
- **C.** Remove the two labels from the rendered pod templates, for example with a post-render step.

Recommendation: A. The network policy design is out of the scope of this RFC. This RFC only records that policies must not select on these labels (check K8 for selectors).

### Q8: The mapping to cloud keys

- **A.** One mechanical rule for both clouds: `.` and `/` to `_`, lowercase, max. 63 characters.
- **B.** One rule for each cloud. Azure keeps `.` and changes only `/`.
- **C.** A short alias for each key in `data.labels`, for example `tenant` for `tenant.<p>/name`.

Recommendation: A. One rule gives one check, and the same query works on both clouds. C gives shorter keys, but the aliases can collide with the keys of other tools in the same cloud project. A has one risk: Azure DNS can refuse `_` or `-` in tag names. Rollout step 6 tests this before the ADR.

### Q9: The scope of the required keys

- **A.** Check only the hand-written objects and the `Namespace` objects. Warn on the rendered upstream objects.
- **B.** Check all objects, also the rendered upstream objects. Use chart values (`commonLabels`) to add the keys.
- **C.** Check only the `Namespace` objects. Cilium and the reports read the namespace labels.

Recommendation: A. The `Namespace` holds the tenant and the trust zone for all its objects. Many upstream charts cannot add labels to all their objects, thus B fails on charts that the repository cannot change.

### Q10: The type of an instance

RFC 0003 keeps free instance names and gives the type of an instance to this RFC.

- **A.** Derive `instance.<p>/type` from `layers`: the first `substrate-*` module, else the first `cluster-*` module, without the layer prefix. No change of the schema.
- **B.** Add a `type` field with an enum to `schemas/instance.schema.json`, for example `kind`, `rpi`, `gke`, `aks`. The label copies the field. A check makes sure that the field matches the modules.
- **C.** No type key. A report reads `instance.yaml`.

Recommendation: A. It adds no new fact, and the value set grows with the modules. B is clearer to read, but the same fact is then in two places.

## Future possibilities

- The zero-trust RFC uses the `network` sub-group, the stable labels and the namespace labels to write `CiliumNetworkPolicy` objects.
- A Kubernetes admission policy, for example a `ValidatingAdmissionPolicy`, can check the required keys in the cluster too, not only in Git.
- A clean-up job can delete the cloud resources of an ephemeral instance when `instance.<p>/ttl` ends.
- Google Cloud Resource Manager tags can control IAM policies on the cloud instances. A later RFC can add them.
- The same prefix and the same data file can go to a template repository for the other repositories of the owner.
