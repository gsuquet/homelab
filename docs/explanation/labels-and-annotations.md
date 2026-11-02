# Labels and annotations

This page tells why the Kubernetes keys, the cloud label keys and their checks have their form. The exact rules are in [Labels and annotations (reference)](../reference/labels-and-annotations.md).

Each upstream chart sets its own keys, and before these rules, the hand-written manifests copied the recommended labels by hand. Later work needs stable keys: policies and quotas need a tenant key, the zero-trust network policies need a trust zone, and I need instance keys to find and delete the cloud resources of a demo instance.

## The prefix `<subgroup>.infra.gsuquet.com`

Kubernetes lets a user set a key without a prefix, but each automated component must use a prefix. Agents and Argo CD are tools of this type. A prefix is a DNS subdomain, and a domain that I control prevents a collision with the keys of other parties.

I use `<subgroup>.infra.gsuquet.com`. I control `gsuquet.com`, and `infra.gsuquet.com` is already the API group of the metadata files. Many projects use the same domain for their API group and for their keys, for example Argo CD with `argoproj.io` and cert-manager with `cert-manager.io`. The same word `infra` is the name of the repository, so a reader who sees a key finds its source ([Repository scope](repository-scope.md)).

I did not select these alternatives:

- **No prefix.** Keys without a prefix can collide with the keys of upstream charts, for example `app` or `component`.
- **`gsuquet.com` alone.** It gives the shortest keys, but my other projects can use the same domain with a different meaning.
- **`homelab.gsuquet.com`.** The repository also holds Google Cloud, Azure and AWS instances, which are not a homelab.
- **`platform.gsuquet.com`.** It is a new word, different from the API group.
- **Another domain**, for example `gsuquet.github.io`. GitHub controls it, and it can change with the account name.

The cost: the prefix is long. A key such as `instance.infra.gsuquet.com/purpose` has 34 characters. I must also keep the registration of `gsuquet.com` and protect the Cloudflare account. If the registration stops, or if somebody takes over the account or its DNS, another party can use the same keys with a different meaning.

## Families, and no keys without a prefix

The prefix of a key gives its family, and the family tells who owns the key. The custom prefix keeps the keys of the repository apart. I did not select these alternatives:

- No rules: each chart and each agent continues to use different keys, and the zero-trust design has no stable base.
- Only the recommended `app.kubernetes.io/*` labels: they have no key for a tenant, a trust zone or an instance.
- Keys without a prefix for the repository: they can collide with the keys of upstream charts.

The keys of the repository use lowercase letters, digits and `-` in their name and their label values. Thus the cloud form of a key has no collision, and each value is also a valid Google Cloud value.

A node label for isolation uses `node-restriction.kubernetes.io/`, because a kubelet cannot change this prefix. Thus a compromised node cannot attract the pods of another trust zone.

## Six sub-groups, three required now

Each subject gets its own sub-group, so that a selector can match one subject by its prefix. One flat prefix, for example `infra.gsuquet.com/tenant`, adds names to one flat list with each subject.

All six sub-groups (`tenant`, `instance`, `ownership`, `network`, `backup`, `cost`) are defined now, so that a check covers each key from the start. Only three are required now, because `network`, `backup` and `cost` have no values yet. A placeholder value such as `unset` has no meaning, and a check would then accept it as valid.

- `tenant` and `network` go only on a `Namespace`, never on a pod. An application author controls the labels of the pods, so a pod could select its own trust zone. Annotations are not an option for them, because selectors and Cilium policies cannot select by annotations.
- The instance keys copy the facts of `instance.yaml`, which `schemas:check` already validates. Thus they have one source.
- The `type` key comes from the cluster module, not from a new `type` field in `instance.yaml`. A field puts the same fact in two places. Without a type key, a cost report cannot group the resources by type.

## Required keys, and a warning for upstream charts

The check denies a missing key on a `Namespace` in `gitops/` and on a hand-written object, and only warns on a rendered upstream object. Many upstream charts cannot add labels to all their objects, so a check on all the rendered objects blocks each PR. A check on the `Namespace` objects only does not cover the `app.kubernetes.io/*` labels of the hand-written charts.

The rendered objects keep `app.kubernetes.io/managed-by: Helm`, although Argo CD applies them. The upstream charts do not always let the repository change this label, and the tracking annotation of Argo CD already tells which `Application` applies an object.

## The `annotation` tracking method, set explicitly

With the `label` method, Argo CD uses `app.kubernetes.io/instance` to find the owner `Application` of an object. Helm and operators also write that label. Thus Argo CD can find the wrong owner, and it can prune the objects of another tool. The `annotation` method has none of these problems.

Since Argo CD 3.0, `annotation` is the default. I still set it explicitly: a later version can change the default, and a check cannot test a missing value. `annotation+label` brings back the conflicts of the label.

## One mapping rule for all the clouds

Google Cloud permits no `.` and no `/` in a label key, and only lowercase letters. One mechanical rule changes each Kubernetes key to one cloud key for Google Cloud, Azure, AWS, Cloudflare and Grafana Cloud. One form needs one check, and one query covers all the clouds.

I did not select these alternatives:

- One form for each cloud: Azure and AWS can keep more of the Kubernetes key. But each form needs its own check, and a query across the clouds needs more than one key.
- Short aliases: they can collide with the keys of other tools in the same cloud project.

The cost: the cloud keys are long, for example `instance_infra_gsuquet_com_name`, and the rule is stricter than AWS needs. Azure DNS tag names do not support "special characters", and the Azure page does not tell if `_` and `-` are special. A test before the first Azure instance answers this (#228).

## Conftest checks with one data file

`mise run lint` already runs Conftest, so the checks run before the merge. One data file holds the reference table and the allowlists, so the table and the checks have one source.

A label cannot give the origin of a rendered object. The Argo CD CRDs have no `helm.sh/chart` label, subcharts use their own name, and a hand-written template can copy the label. The only reliable marker is the `# Source:` comment of `helm template`, and Conftest drops comments. Thus the render step keeps the origin in the file name.

The cost: a data file and its checks are more code to maintain, and the checks of the upstream objects are only warnings.

An `apps` component can create a `Namespace` with any name and any labels. Without limits, it could select its own trust zone or run privileged pods. K14, K4, K15 and `FailOnSharedResource=true` limit it. The `sourceRepos` of the `apps` AppProject is only this repository, so the review of each PR that changes `gitops/apps/` stays the trust boundary.

A Kubernetes admission policy in the cluster can add a second control later.
