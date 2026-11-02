# Labels and annotations

Each upstream chart sets its own label and annotation keys, and each hand-written chart can add more. Without rules, the keys of the platform drift apart, and no tool can rely on them. Some tools need stable keys. A network policy or a quota selects namespaces by their tenant. A zero-trust network policy selects them by their trust zone. A clean-up job finds the cloud resources of a demo instance by the name of the instance.

The label scheme gives these tools one set of keys with one meaning. It has four parts. A prefix marks the keys of the repository. Sub-groups hold the subjects. The checks require some keys. Conftest checks read one data file. This page tells why each part has its form and how the parts fit. The exact rules are in [Labels and annotations (reference)](../reference/labels-and-annotations.md).

## Label or annotation

A label is for selection: a selector, a network policy, a query or a report. An annotation is for everything else: a setting for a controller, a URL, a contact, a long text or JSON. Thus, if no tool and no person selects or queries objects by a key, the key is an annotation. This is the rule of the [Helm best practices](https://helm.sh/docs/chart_best_practices/labels/).

The rule has a direct effect on the scheme. The tenant and the trust zone must be labels, because selectors and Cilium policies cannot select by annotations. A contact or a backup retention is information for a person or a tool, not a selector, so it is an annotation.

## The prefix `<subgroup>.infra.gsuquet.com`

Kubernetes permits a key without a prefix, but it asks each automated component to use a prefix. Argo CD and the agents are components of this type. A prefix is a DNS subdomain. A domain under the control of the repository prevents a collision with the keys of other parties.

The repository uses `<subgroup>.infra.gsuquet.com`. `infra.gsuquet.com` is already the API group of the metadata files `cluster.yaml`, `instance.yaml` and `module.yaml`. Many projects use the same domain for their API group and for their keys, for example Argo CD with `argoproj.io` and cert-manager with `cert-manager.io`. The word `infra` is also the name of the repository, so a reader who sees a key finds its source ([Repository scope](repository-scope.md)).

The other options have problems:

- **No prefix.** Keys without a prefix can collide with the keys of upstream charts, for example `app` or `component`.
- **`gsuquet.com` alone.** It gives the shortest keys, but other projects can use the same domain with a different meaning.
- **`homelab.gsuquet.com`.** The repository also holds Google Cloud, Azure and AWS instances, which are not a homelab.
- **`platform.gsuquet.com`.** It is a new word, different from the API group.
- **Another domain**, for example `gsuquet.github.io`. GitHub controls it, and it can change with the account name.

The prefix has a cost. It is long: `instance.infra.gsuquet.com/purpose` has 34 characters. It also depends on the registration of `gsuquet.com` and on the Cloudflare account that holds its DNS. If the registration stops, or if another party takes over the account, that party can use the same keys with a different meaning. No tool resolves the keys as DNS names, so the only risk is a collision of names.

## Families of keys

The prefix of a key gives its family, and the family tells which party defines the key. The party is Kubernetes, the shared convention of `app.kubernetes.io/*`, a tool such as Helm or Argo CD, or the repository. The checks treat each family differently. A hand-written object can use the keys of a tool. It can use only the Kubernetes keys that Kubernetes documents for users. It can use only the keys of the repository that the data file defines.

Two other designs are possible, and both fail:

- **No rules.** Each chart and each agent continues to use different keys, and the zero-trust design has no stable base.
- **Only the recommended `app.kubernetes.io/*` labels.** They tell what an application is, but they have no key for a tenant, a trust zone or an instance.

The keys of the repository use only lowercase letters, digits and `-` in their name and in their label values. The cause is the cloud. Google Cloud permits no `.` and no `/` in a label key, and only lowercase letters. One mechanical rule gives the cloud form of a key: each `.` and `/` becomes `_`. For example, `instance.infra.gsuquet.com/name` becomes `instance_infra_gsuquet_com_name`. With no `_`, no `.` and no uppercase letter in the name, two keys of the repository cannot have the same cloud form. Each label value is also a valid Google Cloud value.

One rule for all the clouds is stricter than AWS or Azure need. A form for each cloud can keep more of the Kubernetes key. But each form then needs its own check, and a query across the clouds needs more than one key. Short aliases are shorter, but they can collide with the keys of other tools in the same cloud project. The cost of one rule is long cloud keys.

## Sub-groups

Each subject gets its own sub-group: `tenant`, `instance`, `ownership`, `network`, `backup` and `cost`. A selector or a query can then match one subject by its prefix. One flat prefix, for example `infra.gsuquet.com/tenant`, puts the names of all the subjects in one flat list, and the list grows with each subject.

The data file defines all six sub-groups, and K4 checks each key against them. A wrong key fails at once, also in a sub-group that has no required key. Only `tenant` and `ownership` have required keys. `network` and `backup` have no values: K4 refuses each value, so no object can have their keys. A placeholder value such as `unset` has no meaning, and a check would accept it as valid.

The `tenant` and `network` keys go only on a `Namespace`, never on a pod. The author of an application controls the labels of its pods. With a trust zone on the pod, a pod could select its own trust zone. Cilium reads the labels of the `Namespace` of a pod through `io.cilium.k8s.namespace.labels.<key>`. Thus a policy can select the pods by the labels of their namespace ([Cilium: Kubernetes policies](https://docs.cilium.io/en/stable/security/policy/kubernetes/)).

The `instance` and `cost` keys go on cloud resources, never on a Kubernetes object. Each cluster is one instance, so an instance key on its objects adds no information. The instance keys copy the facts of `instance.yaml`, for example its `name` and its `purpose`. `schemas:check` already validates these facts, so the keys have one source. The `type` key comes from the cluster module of the instance, for example `kind` for `cluster-kind`. A new `type` field in `instance.yaml` would put the same fact in two places.

## Required keys, and a warning for upstream charts

The checks are strict on the objects that the repository writes, and lenient on the objects of upstream charts. A key check fails on a hand-written object and only warns on an upstream object. Many upstream charts cannot add labels to all their objects. A strict check on all the rendered objects would block each pull request until each chart changes.

A check on the `Namespace` objects only would be lenient too, but it does not cover the `app.kubernetes.io/*` labels of the hand-written charts. Thus K6 reads each hand-written object, and K7 reads each upstream object.

Some checks of required keys warn on all objects: K5, K6 and K9. The objects of the `argocd` component do not have these keys and settings. A check that fails on the existing files blocks each pull request, so a check starts as a warning when the existing files fail it.

The rendered objects keep `app.kubernetes.io/managed-by: Helm`, although Argo CD applies them. Upstream charts do not always let the repository change this label. The tracking annotation of Argo CD already tells which `Application` applies an object.

## The `annotation` tracking method

With the `label` tracking method, Argo CD uses `app.kubernetes.io/instance` to find the `Application` that manages an object. Helm and operators also write this label. Argo CD can then find the wrong `Application`, and it can prune the objects of another tool. The `annotation` method uses `argocd.argoproj.io/tracking-id`, which only Argo CD writes, and it has none of these problems ([Argo CD: resource tracking](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_tracking/)).

Since Argo CD 3.0, `annotation` is the default ([Argo CD: upgrade from 2.14 to 3.0](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/2.14-3.0/)). K9 still asks for an explicit value. A later version can change the default, and a check reads only the files in Git, not the defaults of Argo CD. `annotation+label` brings back the conflicts of the label.

## Node labels for isolation

A node label for isolation uses the prefix `node-restriction.kubernetes.io/`, not the prefix of the repository. An example is a label for the nodes that can run internet-facing pods. The NodeRestriction admission plugin does not let a kubelet set a label with this prefix ([Kubernetes: admission controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)). Thus a compromised node cannot give itself the label, and it cannot attract the pods of another trust zone. K2 permits the prefix on hand-written objects.

## Conftest checks with one data file

`mise run lint` already runs Conftest, so the checks run before the merge, on each pull request. One data file, `policy/data/labels.yaml`, holds the sub-groups, the keys, the required keys and the allowlists. The checks read the file and hold no list of their own. A change of a rule is a change of data, and the table and the checks cannot disagree.

A check must know the origin of each rendered object: hand-written or upstream. A label cannot give it. The Argo CD CRDs have no `helm.sh/chart` label, subcharts use their own name, and a hand-written template can copy the label. The only reliable marker is the `# Source:` comment of `helm template`, and Conftest drops comments. Thus `manifests:render` keeps the origin in the file name, with the prefix `upstream--`.

The cost: the data file and its checks are more code to maintain, and the checks of the upstream objects are only warnings.

An admission policy in the cluster is another control. It sees each object that reaches the API server, also the objects that Terraform or a person creates. The Conftest checks see only the files in Git, but they stop a wrong key before the merge.

## Trust boundary of an `apps` component

An `apps` component can create a `Namespace` with any name and any labels. Without limits, it could select its own trust zone, or run privileged pods. Three checks limit it:

- K4 permits only the tenant and the `network` values that the data file gives to the component.
- K14 permits only the `restricted` and `baseline` Pod Security levels.
- K15 permits only the namespace of the component in `cluster.yaml`, and refuses the reserved namespaces.

The `apps` AppProject accepts sources only from this repository. The review of each pull request that changes `gitops/apps/` or the data file is thus the trust boundary.

## Related pages

- [Labels and annotations (reference)](../reference/labels-and-annotations.md)
- [Label a GitOps component](../how-to/label-a-gitops-component.md)
- [GitOps with Argo CD](gitops-with-argocd.md)
- [Rendered manifests pattern](rendered-manifests-pattern.md)
- [Repository scope](repository-scope.md)
