# OpenChoreo platform (reference)

This page lists the specs of OpenChoreo v1.3.3 on `kind-local` (milestone M2): the components, the layout, the kinds, the namespaces, the AppProject rules, the admission policies, the checks and the done criteria. The reasons are in [OpenChoreo platform](../explanation/openchoreo-platform.md). The steps are in [Roll out OpenChoreo](../how-to/roll-out-openchoreo.md).

## What OpenChoreo needs

The [installation guide for an existing cluster](https://openchoreo.dev/docs/getting-started/try-it-out/on-your-environment/) installs these items, in this order. The table compares them with the repository on `main` (2026-11-02).

| Item | OpenChoreo v1.3.3 guide | Repository now | Plan for M2 |
| --- | --- | --- | --- |
| Kubernetes | 1.34 or later, LoadBalancer support, a default StorageClass | `kindest/node` v1.36.1, by digest | A 1.37 node image, by digest. 1.37 meets the minimum of 1.34. The OpenChoreo k3d tests use 1.36.1 (`rancher/k3s:v1.36.1-k3s1`), thus 1.37 is not tested upstream. kind has no LoadBalancer. |
| Gateway API CRDs | v1.5.1, `standard` channel | v1.6.2, `standard` channel, from Terraform | Keep v1.6.2, if the R3 checks pass. |
| cert-manager | v1.19.4. The topology page requires 1.12 or later on each plane cluster. | Module `bootstrap-cert-manager` (v1.21.2), not used on `kind-local` | A `cert-manager` component in `gitops/infrastructure/`, chart v1.21.2. |
| External Secrets Operator | v2.0.1, required before any plane chart | None | The latest minor (2.14) from [Secrets (reference)](secrets.md). ESO 2.0 is at its end of life. |
| kgateway | v2.3.11 (CRDs and controller) | None. Cilium Gateway API support is off. | A `kgateway` component. |
| OpenBao | v0.25.6, dev mode, with a `ClusterSecretStore` named `default` | None. The repository uses SOPS. | Not installed. |
| ThunderID | v1.0.1, the default OpenID Connect provider | None | A `thunder` component. |
| OpenChoreo planes | v1.3.3 charts from `oci://ghcr.io/openchoreo/helm-charts` | None | Control plane and data plane. |
| Argo Workflows | Bundled in the workflow plane. The guide overrides the image to v4.0.15, because the chart default v4.0.8 trusts compromised eMudhra CAs. | None | Not in M2. |
| Image registry | `twuni/docker-registry` and a zot build cache for local builds | None | Not in M2. |
| Observability modules | OpenSearch for logs and traces, Prometheus for metrics, an OpenTelemetry Collector for events | None | Not in M2. Heavy. |
| Cilium | Not required. The `networking-cilium` module is optional. | v1.20.0, kube-proxy replacement, from Terraform | No conflict. Stays at 1.20.0. |
| Kyverno | Not required. The v1.3.3 source has no reference to Kyverno. | Dropped on 2026-10-31 | No conflict. |
| Argo CD | Not installed. The GitOps guide uses Flux CD, and Flux CD is the default GitOps module. | Argo CD manages itself from `gitops/` | No second Argo CD. |

The OpenChoreo images and the portal image have `linux/amd64` and `linux/arm64` builds. The third-party images are not verified (refer to [Open checks](#open-checks)).

## Components in `cluster.yaml`

M2 alone, in `gitops/clusters/kind-local/cluster.yaml`:

```yaml
infrastructure:
  - name: argocd
    namespace: argocd
  - name: cert-manager
    namespace: cert-manager
  - name: external-secrets          # from the secrets design
    namespace: external-secrets
  - name: kgateway
    namespace: kgateway-system
    dependsOn: [cert-manager]
  - name: thunder
    namespace: thunder
    dependsOn: [external-secrets, kgateway]
  - name: openchoreo-control-plane
    namespace: openchoreo-control-plane
    dependsOn: [cert-manager, external-secrets, kgateway, thunder]
  - name: openchoreo-data-plane
    namespace: openchoreo-data-plane
    dependsOn: [openchoreo-control-plane]
apps:
  - name: choreo-sandbox            # placeholder until the tenants design (#182)
    namespace: sandbox
    dependsOn: [openchoreo-data-plane]
```

M1 and M2 together:

```yaml
infrastructure:
  - name: argocd
    namespace: argocd
  - name: cert-manager
    namespace: cert-manager
  - name: external-secrets          # secrets design
    namespace: external-secrets
  - name: agentgateway              # M1, no secret
    namespace: agentgateway-system
  - name: kgateway
    namespace: kgateway-system
    dependsOn: [cert-manager]
  - name: kagent                    # M1
    namespace: kagent
    dependsOn: [agentgateway]
  - name: thunder
    namespace: thunder
    dependsOn: [external-secrets, kgateway]
  - name: openchoreo-control-plane
    namespace: openchoreo-control-plane
    dependsOn: [cert-manager, external-secrets, kgateway, thunder]
  - name: openchoreo-data-plane
    namespace: openchoreo-data-plane
    dependsOn: [openchoreo-control-plane]
apps:
  - name: choreo-sandbox            # placeholder until the tenants design (#182)
    namespace: sandbox
    dependsOn: [openchoreo-data-plane]
```

- The sync waves are global across all `Application` objects. `agentgateway` is in the first wave with `argocd`, `cert-manager` and `external-secrets`. If it is not `Healthy`, each later wave waits.
- No `secrets:apply` gates the `agentgateway` `Application` ([kagent and agentgateway (reference)](kagent-and-agentgateway.md)).
- The workflow plane and the observability plane are not in M2.
- The `choreo-sandbox` entry is a placeholder. The tenants design ([issue #182](https://github.com/gsuquet/homelab/issues/182)) replaces it.

## Layout

```text
gitops/
├── infrastructure/
│   ├── cert-manager/sources/{Chart.yaml,values.yaml}
│   ├── kgateway/sources/{Chart.yaml,values.yaml,templates/}
│   ├── thunder/sources/{Chart.yaml,values.yaml}
│   ├── openchoreo-control-plane/sources/
│   │   ├── Chart.yaml             # depends on openchoreo-control-plane 1.3.3
│   │   ├── values.yaml
│   │   └── templates/             # Namespace, CA issuer, cluster-scoped platform definitions
│   └── openchoreo-data-plane/sources/
│       ├── Chart.yaml             # depends on openchoreo-data-plane 1.3.3
│       ├── values.yaml
│       └── templates/             # Namespace, ClusterDataPlane, agent role
├── apps/
│   └── choreo-sandbox/sources/
│       └── templates/             # developer kinds only: Project, Components. The tenants design replaces this path.
└── clusters/kind-local/
    ├── cluster.yaml
    ├── values/<component>.yaml    # kind-local values: hostnames, ports
    └── rendered/<component>/
```

Terraform makes these items, from the data of the `kind` network, in the `cluster-kind` or `bootstrap-cilium` module:

- One `CiliumLoadBalancerIPPool` from the subnet of the kind Docker network. L2 announcements stay off. The host uses `kubectl port-forward`.
- The CoreDNS `rewrite` in the `coredns` ConfigMap of `kube-system`, which sends the OpenChoreo hostnames to the kgateway Service of the control plane.

Terraform also manages the Gateway API CRDs. kgateway, OpenChoreo and agentgateway do not install them.

## Rules for an author

- A platform definition goes in the `infrastructure` group. The cluster-scoped forms (`ClusterComponentType`, `ClusterTrait`, `ClusterProjectType`, `ClusterWorkflow`) go in `gitops/infrastructure/openchoreo-control-plane/sources/templates/`.
- The `ClusterDataPlane` goes in the data plane component. Only the `infrastructure` AppProject can create cluster-scoped objects.
- The platform manages the OpenChoreo namespace of each tenant, its `Environment` objects and its `DeploymentPipeline`. A tenant writes only the developer kinds. The tenants design ([issue #182](https://github.com/gsuquet/homelab/issues/182)) sets where each of them goes.
- An author does not write a `Deployment` or a `Service` for an OpenChoreo application. OpenChoreo makes them.
- An author does not add the `dp-*` namespaces to `cluster.yaml`.
- To promote or roll back a release, change the `ReleaseBinding` in Git. The `occ` commands that change the API directly cause drift, and Argo CD reverts it.
- Each cluster agent RBAC extension is its own `ClusterRole` and `ClusterRoleBinding` in the data plane component, with only the kinds and verbs that it needs.
- Third-party controllers do not go into the plane namespaces.

## OpenChoreo kinds

All 36 CRDs of the [control plane chart](https://github.com/openchoreo/openchoreo/tree/v1.3.3/install/helm/openchoreo-control-plane/crds) are in the API group `openchoreo.dev`, version `v1alpha1` ([Developer abstractions](https://openchoreo.dev/docs/concepts/developer-abstractions/), [Platform abstractions](https://openchoreo.dev/docs/concepts/platform-abstractions/)). The table leaves out a few of them, for example `ObservabilityAlertsNotificationChannel`.

| Written by | Kind | Scope | Purpose |
| --- | --- | --- | --- |
| Platform | A Kubernetes `Namespace` with the label `openchoreo.dev/control-plane: "true"` | Cluster | The unit that groups projects. OpenChoreo has no `Organization` CRD in v1.3. |
| Platform | `Environment` | Namespace | A delivery stage, for example `development`. It points to one data plane (`dataPlaneRef`, immutable). |
| Platform | `DeploymentPipeline` | Namespace | The permitted promotion paths between the environments. |
| Platform | `DataPlane`, `ClusterDataPlane` | Namespace, cluster | The registration of a data plane: agent CA, gateway, secret store. |
| Platform | `WorkflowPlane`, `ObservabilityPlane` and their `Cluster*` forms | Namespace, cluster | The registration of the optional planes. |
| Platform | `ComponentType`, `ClusterComponentType` | Namespace, cluster | A deployment template with a workload type (`deployment`, `statefulset`, `cronjob`, `job` or `proxy`), a parameter schema and CEL resource templates. |
| Platform | `Trait`, `ClusterTrait` | Namespace, cluster | A reusable addition to a component. It creates resources or patches them with JSON Patch. |
| Platform | `ProjectType`, `ClusterProjectType` | Namespace, cluster | A template for the data plane namespace of a project. It must contain a `v1/Namespace`. |
| Platform | `ResourceType`, `ClusterResourceType` | Namespace, cluster | A template for a managed dependency, for example a database. |
| Platform | `Workflow`, `ClusterWorkflow` | Namespace, cluster | A build or automation template on Argo Workflows. |
| Platform | `AuthzRole`, `ClusterAuthzRole` and their bindings | Namespace, cluster | The RBAC of the OpenChoreo API. |
| Developer | `Project` | Namespace | A bounded context of components. It becomes one "cell": one namespace in each environment. |
| Developer | `Component`, `Workload` | Namespace | A deployable unit and its runtime contract: container, endpoints, dependencies. |
| Developer | `ReleaseBinding`, `ProjectReleaseBinding`, `ResourceReleaseBinding` | Namespace | They bind an immutable release to an environment. Promotion moves the binding. |
| Developer | `Resource` | Namespace | A dependency of a project, from a `ResourceType`. |
| Developer | `SecretReference` | Namespace | A reference to a key in the secret store. The cells read the key through an `ExternalSecret`. |
| Developer | `WorkflowRun` | Namespace | One run of a `Workflow`. |
| Controller | `ComponentRelease`, `ProjectRelease`, `ResourceRelease`, `RenderedRelease` | Namespace | Immutable snapshots. The controllers make them. They are not in Git. |

The developer list for the AppProject check: `Project`, `Component`, `Workload`, `ReleaseBinding`, `ProjectReleaseBinding`, `ResourceReleaseBinding`, `Resource` and `SecretReference`.

## Namespaces

| Namespace | Managed by | `tenant.<p>/name` | Pod Security | Set by |
| --- | --- | --- | --- | --- |
| `openchoreo-control-plane`, `openchoreo-data-plane`, `kgateway-system`, `thunder`, `cert-manager`, `external-secrets` | `infrastructure` AppProject | `platform` | Per the chart. The implementation PR records the level. | The `Namespace` template of each component |
| `sandbox` (the OpenChoreo namespace of a tenant) | The platform. The tenants design sets the AppProject. | The tenant, for example `sandbox` | `restricted` (no pods run in it) | The platform, in the layout of the tenants design |
| `dp-sandbox-*` (cell namespaces) | OpenChoreo | The tenant of the OpenChoreo namespace | `restricted` or `baseline` | The `ClusterProjectType`. An admission policy enforces it. |
| `openchoreo-kv-<namespace>` | The OpenChoreo API | `platform` | `restricted` | Only with `secretManagement` on. Not in M2. |

- The cell namespace name is `dp-{namespace}-{project}-{environment}-{hash}`.
- A tenant name is a DNS label without `-`. It is equal to the name of the OpenChoreo namespace of the tenant. A schema or Conftest check enforces the rule on the OpenChoreo namespaces in `gitops/apps/`.
- No OpenChoreo object goes in `default`. K15 reserves it ([Labels and annotations (reference)](labels-and-annotations.md)).

### Cell namespace labels

The `ClusterProjectType` sets these labels on each cell namespace:

- `tenant.infra.gsuquet.com/name` from `${metadata.projectNamespace}`, the OpenChoreo namespace of the project.
- `ownership.infra.gsuquet.com/owner: gsuquet`.
- The Pod Security labels.

The template puts the platform map last: `oc_merge(environmentConfigs.namespaceLabels, <platform labels>)`. The platform map also carries the `openchoreo.dev/*` labels from `metadata.labels`.

## Network policy

- The `ClusterDataPlane` `default` has the annotation `openchoreo.dev/networkpolicyprovider: cilium`.
- The controller renders one `CiliumNetworkPolicy` `openchoreo-<component>` (`cilium.io/v2`) for each component, with ingress rules only.
- HTTP, GraphQL, WebSocket and gRPC endpoints get an allow-all L7 rule (`toPorts.rules.http: [{}]`). Other ports get L4 rules. A component without endpoints gets `ingress: [{}]`.
- Cilium stays at 1.20.0, with Gateway API support off.
- The values of the `networking-cilium` module (Hubble Relay, Hubble metrics, the `ServiceMonitor`, `envoy.httpRetryCount: 0`, `HUBBLE_RELAY_ADDR`) are not in M2.
- The M1 policies in `kagent` and `agentgateway-system` stay standard `NetworkPolicy` objects.

## Secret store

| Rule | Value |
| --- | --- |
| Store | One `ClusterSecretStore` `oc-<tenant>` for each OpenChoreo tenant ([Secrets (reference)](secrets.md)) |
| Source namespace | Only `secret-seeds-oc-<tenant>`, set explicitly as `remoteNamespace` |
| Authentication | `auth.serviceAccount.namespace` set explicitly. No referent authentication into a cell. |
| Conditions | Exactly one: `namespaceRegexes: ["^dp-<tenant>-"]` |
| `ClusterDataPlane` | `secretStoreRef` unset |
| Store name in templates | `oc-${metadata.componentNamespace}` in a `ClusterComponentType` or `ClusterTrait`, `oc-${metadata.resourceNamespace}` in a `ClusterResourceType`, `oc-${metadata.projectNamespace}` in a `ClusterProjectType` |
| Data key | Each seed has one data key, `value`. Each `remoteRef` sets `property: value`. |
| Managed secret API | `features.secretManagement.enabled` stays off. |
| Platform components | Each one uses its own store `secrets` and ServiceAccount `eso-seed-reader` ([Add a secret consumer](../how-to/add-a-secret-consumer.md)). |

SC9 checks the store rules in Git. SC9a, a `ValidatingAdmissionPolicy` on `ClusterSecretStore` objects, enforces them in the cluster.

## AppProject rules

The `apps` AppProject has these rules. Step R5 makes them in one change, also for the M1 needs ([kagent and agentgateway (reference)](kagent-and-agentgateway.md)).

| Rule | Value |
| --- | --- |
| `namespaceResourceBlacklist`, group `openchoreo.dev`, platform kinds | `ComponentType`, `ProjectType`, `Trait`, `ResourceType`, `Workflow`, `DataPlane`, `WorkflowPlane`, `ObservabilityPlane`, `AuthzRole`, `AuthzRoleBinding` |
| `namespaceResourceBlacklist`, group `openchoreo.dev`, platform-managed kinds | `Environment`, `DeploymentPipeline` |
| `namespaceResourceBlacklist`, group `openchoreo.dev`, release kinds | `kind: "*Release"`: `ComponentRelease`, `ProjectRelease`, `ResourceRelease`, `RenderedRelease`. The glob does not match `ReleaseBinding`, `ProjectReleaseBinding` or `ResourceReleaseBinding`. |
| `namespaceResourceBlacklist`, group `openchoreo.dev`, kinds without a plane in M2 | `WorkflowRun`, `ObservabilityAlertsNotificationChannel` |
| `namespaceResourceBlacklist`, other groups | All kinds of `external-secrets.io`, `agentgateway.dev` and `kagent.dev` |
| `clusterResourceWhitelist` | `Namespace` only, without a name |
| `clusterResourceBlacklist`, `Namespace` names | `dp-*`, `openchoreo-*`, `secret-seeds-*`, `agentgateway-system`, `kagent`, `thunder`, `kgateway-system`, `cert-manager`, `external-secrets`, `kube-*`, `argocd`, `default` |
| Destinations | Only the namespaces of `apps[].namespace` in `cluster.yaml`, from the `argocd` chart |

- The blacklist wins over the whitelist.
- The repository runs Argo CD v3.5.6 (chart 10.11.6). Its rendered `AppProject` CRD has the `name` field with glob patterns.
- A check reads the rendered CRDs of each OpenChoreo chart. It fails when a namespaced `openchoreo.dev` kind is on neither the developer list nor the blacklist.
- The tenants design changes the blacklist into one generated AppProject for each tenant, with a whitelist of the developer kinds.

## Admission policies

Both policies are `ValidatingAdmissionPolicy` objects in the `openchoreo-control-plane` component, with `validationActions: [Deny]`.

### Policy 1: cell namespaces

It selects the `Namespace` objects whose name starts with `dp-`, on create and update. It refuses the namespace if a rule fails.

1. Only the ServiceAccount of the data plane cluster agent can create or update a `dp-*` namespace.
2. The value of `tenant.infra.gsuquet.com/name` agrees with the name: the name starts with `dp-<tenant>-`.
3. The `ownership.infra.gsuquet.com/owner` label and the Pod Security labels are present.

### Policy 2: writes of the cluster agent

It matches each request from the agent ServiceAccount, by `request.userInfo.username`.

1. A namespaced write goes only to a namespace whose name matches `^dp-`, or to `openchoreo-data-plane`.
2. No write on `rbac.authorization.k8s.io`, on `admissionregistration.k8s.io` or on `clustersecretstores`.

RBAC protects the policy objects, because Kubernetes exempts `ValidatingAdmissionPolicy` and `ValidatingAdmissionPolicyBinding` from policies made through the API ([API kinds exempt from admission validation](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/#api-kinds-exempt-from-admission-validation)).

## Cluster agent role

| Phase | Role | Bounds |
| --- | --- | --- |
| First sync of M2 | The upstream role of the data plane chart | `kind-local` only. No tenant except `sandbox`. The tenant limits in place. No OpenChoreo on `olympus` or in the cloud. |
| Before the end of M2 | The repository role: `clusterAgent.rbac.create: false`, with a repository `ClusterRole` and `ClusterRoleBinding` | No RBAC kinds, no `clustersecretstores`, only the namespaced kinds that the component types use. Required before a second tenant. |

The cluster agent stays a trusted Secret reader with both roles (SC16, [Secrets (reference)](secrets.md)). The other trusted readers that this design adds: the OpenChoreo controller manager, `openchoreo-api` and the cluster gateway.

## Conftest checks

| Check | Scope | Rule |
| --- | --- | --- |
| Cell labels | `ClusterProjectType` in `rendered/` | The label merge has the form `oc_merge(environmentConfigs.namespaceLabels, <platform labels>)`. |
| No default store | Platform templates in `rendered/` | No `${dataplane.secretStore}`. |
| Seed property | `SecretReference` in `gitops/apps/`, `ExternalSecret` in the platform templates | Each `remoteRef` has `property: value`. |
| Tenant name | OpenChoreo namespaces in `gitops/apps/` | A DNS label without `-`. A schema or Conftest check. |
| AppProject coverage | Rendered CRDs of each OpenChoreo chart | Each namespaced `openchoreo.dev` kind is on the developer list or on the blacklist. |

## Chart features

- The 36 CRDs render with `--include-crds`, apply with `ServerSideApply=true`, and get `Prune=false`.
- The controller manager has validating and mutating webhooks with `failurePolicy: Fail` for the `openchoreo.dev` kinds, on create and update.
- The authz bootstrap `Job` and its RBAC have `helm.sh/hook: post-install,post-upgrade` and `hook-delete-policy: hook-succeeded`.
- The template `remote-connect-signing-key.yaml` uses `lookup`. It stays inactive (`remoteConnect.enabled: false`).
- `ClusterDataPlane.spec.clusterAgent.clientCA.secretKeyRef` refers to `cluster-agent-tls`. One cert-manager CA `ClusterIssuer` signs the cluster gateway and the agent certificates. Git holds no certificate.
- The managed secret API, the remote-connect router and the AI features (the SRE agent, the FinOps agent, the portal assistant) stay off.
- ThunderID has no sample users with fixed passwords. Test user passwords come from the secret store.

## Requirements for `olympus` and the cloud

| Requirement | Value | Source |
| --- | --- | --- |
| Kubernetes | 1.34 or later | [On your environment](https://openchoreo.dev/docs/getting-started/try-it-out/on-your-environment/) |
| Cluster features | A LoadBalancer implementation and a default StorageClass | Same |
| Development node | 1 node, 4 CPU cores, 8 GB RAM, minimum | [Deployment topology](https://openchoreo.dev/docs/platform-engineer-guide/deployment-topology/) |
| High availability | 3 nodes, each 4 CPU cores and 8 GB RAM, minimum | Same |
| cert-manager | 1.12 or later on each cluster with a plane | Same |
| External Secrets Operator | On each cluster that syncs secrets | [Secret management](https://openchoreo.dev/docs/platform-engineer-guide/secret-management/) |
| Build scratch disk | About 12 GiB for each build pod | [Production sizing](https://openchoreo.dev/docs/platform-engineer-guide/production-sizing/) |
| Example, 50 components in 2 environments | Control plane 1 vCPU and 1.2 GiB, workflow plane 2.3 vCPU and 4.5 GiB, observability plane 3 vCPU and 19.1 GiB | Same |
| arm64 | OpenChoreo and portal images: yes. Third-party images: not verified. | [Open checks](#open-checks) |
| Multi-cluster network | Only the cluster gateway of the control plane must be reachable. The agents connect outbound. | [Deployment topology](https://openchoreo.dev/docs/platform-engineer-guide/deployment-topology/) |

## Done criteria for M2

Each item must be true on a `kind-local` cluster that `mise run instance:up` makes from an empty state, on the commit of the implementation PR, after a run of `mise run secrets:apply kind-local`. The machine is the 16 GB laptop.

### Positive criteria

1. Each `Application` of the M2 components is `Synced` and `Healthy` within its sync timeout of 900 seconds. Also, `kubectl wait --for=condition=Ready` succeeds on each `Environment`, `Project`, `Component` and `ReleaseBinding` in `sandbox`, because Argo CD has no health check for these kinds.
2. `kubectl get clusterdataplane default -o jsonpath='{.status.agentConnection.connected}'` returns `true`.
3. The sample component `go-greeter-service` from [`samples/from-image/`](https://github.com/openchoreo/openchoreo/tree/v1.3.3/samples/from-image/go-greeter-service) is in the `sandbox` tenant. Its `ReleaseBinding` for `development` is ready.
4. An HTTP request through `kubectl port-forward` to the data plane Gateway, with the host of the `HTTPRoute`, returns status 200 from the sample.
5. The cell namespace of the sample has `tenant.infra.gsuquet.com/name: sandbox`, `ownership.infra.gsuquet.com/owner: gsuquet` and a Pod Security `enforce` label.
6. A `SecretReference` of the sample to a test seed in `secret-seeds-oc-sandbox` gives a cell Secret whose value is equal to the seed value, not a JSON object. A `SecretReference` without `property: value` makes `mise run lint` fail.
7. The cell namespace of the sample has a `CiliumNetworkPolicy` whose name starts with `openchoreo-`, and no OpenChoreo `NetworkPolicy`. Check: `kubectl -n <cell> get ciliumnetworkpolicies,networkpolicies`. The four Cilium checks of [Open checks](#open-checks) pass.

### Negative criteria

1. A tenant `ComponentType`, a tenant `RenderedRelease` or a tenant `ComponentRelease` in the tenant source of `sandbox` makes the sync fail, because the tenant AppProject does not permit the kind. The tenant source is `gitops/apps/choreo-sandbox/`, or its replacement in the tenants layout. The tenant AppProject is the `apps` AppProject, or its replacement. A tenant `Namespace` with the name `dp-sandbox-test` also makes the sync fail.
2. A tenant `SecretReference` to a platform key, for example the ThunderID admin credentials, gives an `ExternalSecret` that does not become ready.
3. A login to the console with `admin@openchoreo.dev` and its documented default password fails.
4. A `ProjectReleaseBinding` that sets `tenant.infra.gsuquet.com/name` in `namespaceLabels` does not change the label of the cell. The admission policy refuses a `dp-sandbox-test` namespace with correct labels from the admin (rule 1). It also refuses a `dp-sandbox-test` namespace with a wrong `tenant` label from `kubectl --as=system:serviceaccount:openchoreo-data-plane:<agent ServiceAccount>` (rule 2).
5. A tenant `Pod` with the destination `agentgateway-system` makes the sync of `choreo-sandbox` (or its replacement) fail. The second admission policy refuses a `Pod` that the agent ServiceAccount writes into `kagent` (`kubectl --as=`). As the agent ServiceAccount, these are refused too: a `Pod` with `serviceAccountName: agentgateway-proxy` in `agentgateway-system`, and `create serviceaccounts/token` for `agentgateway-proxy`. That `ServiceAccount` has the Google identity of M1.
6. Apply a temporary `CiliumNetworkPolicy` that denies the egress of the agent to the cluster gateway. Argo CD does not track it, thus `selfHeal` keeps it, and no sync setting changes. A change of the sync of a child `Application` fails, because the `argocd` `Application` heals it. Within 120 seconds, `.status.agentConnection.connected` is not `true`. A new `ReleaseBinding` is not ready after 300 seconds. Then delete the policy.
7. Each of these calls with `kubectl --as=system:serviceaccount:openchoreo-data-plane:<agent ServiceAccount>` is refused: `create clusterrolebinding`, `delete validatingadmissionpolicy` and `delete validatingadmissionpolicybinding` for the two policies, and `create clustersecretstore`. Run them under the upstream role, and again under the repository role.

### General criteria

1. No OpenChoreo object is in the `default` namespace. `mise run lint` passes. No rendered `Secret` has `data` or `stringData`, except the narrow SC7 exception for `kagent-postgresql` in `gitops/clusters/kind-local/rendered/kagent/` ([Secrets (reference)](secrets.md)).
2. Each chart has an exact version, and each image that the charts permit has a digest. `mise run instance:down`, then `mise run instance:up` and `mise run secrets:apply kind-local`, gives the same result.
3. The PR records the memory limit of the Docker VM. The limit is 12 GiB or more for the test. The PR records the peak memory and CPU of the kind node containers, from the start of `instance:up` to the end of negative criterion 6. This includes the first sync and the image pulls. It samples `docker stats --no-stream` every 5 seconds, or reads `memory.peak` of each node cgroup. It does this once with M2 alone, and once with M1 and M2 together. The peak with M1 and M2 is below 12 GiB, so that 4 GB stay for macOS on the 16 GB laptop. No pod is `OOMKilled`, and no kind node container shows `OOMKilled` in `docker inspect`. These numbers also feed the plan for `olympus`.
4. Before the end of M2, the data plane chart runs with `clusterAgent.rbac.create: false`, and the repository manages the agent `ClusterRole` and `ClusterRoleBinding`. All positive criteria pass with this role.

## Open checks

The implementation PR settles these items.

- **kind.** The full flow on kind works, because no OpenChoreo test uses kind.
- **OIDC issuer.** The k3d issuer URL has a port (`thunder.openchoreo.localhost:8080`). A CoreDNS rewrite to a kgateway Service on port 80 does not match that issuer inside the cluster, and the pods cannot reach a `port-forward` on the host. Select the hostnames and ports so that the browser and the pods use the same issuer URL.
- **Kubernetes 1.37.** OpenChoreo v1.3.3 runs on the 1.37 node image. Its docs require 1.34 or later, and its tests use 1.36.1.
- **ESO.** OpenChoreo v1.3.3 with ESO 2.14 and `external-secrets.io/v1`, on Kubernetes 1.37. No chart value or controller code expects a store named `default`.
- **Per-tenant store.** The regex condition `^dp-<tenant>-` of each `oc-<tenant>` store matches only the cells of that tenant. The variables `metadata.resourceNamespace` and `metadata.projectNamespace` give the same name as `metadata.componentNamespace`.
- **Releases.** `ReleaseBinding.releaseName` and `ProjectReleaseBinding.projectRelease` accept a release that the controller did not create. This confirms the need of the `*Release` entry.
- **Cell names.** The truncation of long cell namespace names (`MaxNamespaceNameLength`) keeps the prefix `dp-<tenant>-`.
- **Admission policy.**
  - The cell policy: `resourceRules` lists `namespaces` only, without subresources.
  - The second policy: its `resourceRules` cover the subresource `serviceaccounts/token`, so that negative criterion 5 holds.
  - Objects with `metadata.deletionTimestamp` are exempt, so that the manual finalizer removal of the rollback succeeds ([Roll back](../how-to/roll-out-openchoreo.md#roll-back)).
  - The CEL of each `ValidatingAdmissionPolicy`, with `matchConditions` on the name, `validationActions: [Deny]`, and the user name of the agent ServiceAccount.
  - The platform map of `oc_merge` also carries the `openchoreo.dev/*` labels from `metadata.labels`. Else the controller loses these labels, and the policy refuses each cell.
- **Default login.** Negative criterion 3 as a request to the ThunderID authentication endpoint, with the expected status.
- **Gateway API.** kgateway v2.3.11 with the v1.6.2 CRDs of Terraform. The kgateway charts do not install Gateway API CRDs.
- **Load balancer.** Each Gateway becomes `Programmed` with an address from the LB IPAM pool.
- **Cilium provider on 1.20.0.** The module documents Cilium 1.19.x only. Four checks:
  1. The rendered `openchoreo-*` `CiliumNetworkPolicy` objects are valid and enforced on Cilium 1.20.0. `kubectl get cnp -A` lists them with no error status, and Cilium reports no policy error.
  2. The case of a component without endpoints: its policy has `ingress: [{}]`, Cilium accepts it, and it denies the traffic that no rule permits.
  3. An allow and deny traffic matrix with `curl` from pods: the same project, another project of the tenant, another namespace, and the system components. Each result matches the three ingress rules of `networkpolicy.go`.
  4. The rollback: after the removal of the annotation, the controller renders standard `NetworkPolicy` objects, and the old `CiliumNetworkPolicy` objects go away.

  Also: the annotation on the `ClusterDataPlane` is the switch. The module README says so, but the controller code that reads it is not found (not verified).
- **CRDs.** The 36 CRDs render with `--include-crds`, apply with `ServerSideApply=true`, and get `Prune=false`.
- **Webhooks.** The sync waves keep the platform definitions after the webhook is ready.
- **Helm hooks.** Argo CD maps `helm.sh/hook: post-install,post-upgrade` to `PostSync` for Helm sources ([Argo CD: Helm](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)). Check that it does the same for the rendered manifests. With `hook-delete-policy: hook-succeeded`, the hook runs again at each automated sync. Check that the authz bootstrap is idempotent, and that it does not reset later authz changes. Record the permissions of its RBAC.
- **`lookup`.** The template `remote-connect-signing-key.yaml` stays inactive (`remoteConnect.enabled: false`). With `helm template`, it makes a new private key at each render. List each `Secret` that a chart renders.
- **Data plane registration.** `ClusterDataPlane.spec.clusterAgent.clientCA.secretKeyRef` refers to `cluster-agent-tls`. One CA `ClusterIssuer` signs the cluster gateway and the agent certificates. Thus the agent can read the server CA from its own Secret, and no copy of `cluster-gateway-ca` is necessary.
- **Tenant limits.** A namespaced `ComponentType` can emit a `ClusterRoleBinding` through the agent with the upstream role. This shows the need of the blacklist. The CEL of the `ValidatingAdmissionPolicy`.
- **SC16 and the gateway charts.** The roles of kgateway v2.3.11 and ThunderID against SC16 ([Secrets (reference)](secrets.md)). kgateway can read Secrets in all namespaces for TLS.
- **Events.** The agent writes events about cluster-scoped objects, for example a cell `Namespace`, into `default`. The second admission policy refuses them. Check that this only adds log noise, or permit `events` in `default`.
- **Who creates cells.** In the single-cluster mode, the controller manager or the agent creates the `dp-*` namespaces. The controller manager also has `create` on `namespaces`. Rule 1 of the cell policy names the correct ServiceAccount.
- **Agent role.** OpenChoreo works with `clusterAgent.rbac.create: false` and a repository role without the RBAC kinds and `clustersecretstores`. The flag turns off both the `ClusterRole` and the `ClusterRoleBinding`, thus the repository manages both. Record the name of the agent ServiceAccount for the binding.
- **Labels.** The charts accept `global.commonLabels` for the labels of [Labels and annotations (reference)](labels-and-annotations.md).
- **Pins.** Each chart pin is the OCI chart version. The `Chart.yaml` files on the Git tag carry `0.0.0-latest-dev`, and CI writes the version at package time. Each image field accepts a digest. Check the Cosign signature of each pinned OpenChoreo image ([`release.yml`](https://github.com/openchoreo/openchoreo/blob/v1.3.3/.github/workflows/release.yml)).
- **arm64.** OpenChoreo builds its 13 images for `linux/amd64` and `linux/arm64` ([`make/docker.mk`](https://github.com/openchoreo/openchoreo/blob/v1.3.3/make/docker.mk)). The portal image has both ([`publish-candidates.yml`](https://github.com/openchoreo/backstage-plugins/blob/main/.github/workflows/publish-candidates.yml)). Check kgateway, ThunderID and the sample.
- **Resources.** The requests of the chart defaults are about 750m CPU and 900 MiB for the control plane, and about 150m CPU and 256 MiB for the data plane, without kgateway and ThunderID. Compare them with the measurement of general criterion 3.
- **kagent.** The OpenChoreo `Workload` contract against a kagent `Agent`, as input for M3.

## Open decisions

### The `cert-manager` namespace and K15

[Labels and annotations (reference)](labels-and-annotations.md) lists `cert-manager` in the K15 reserved list as a namespace that Terraform creates. This design installs cert-manager on `kind-local` as a GitOps component in `gitops/infrastructure/`, not through Terraform. K15 applies the reserved list only to `apps` namespaces, thus both rules can stay. Options:

- A: keep `cert-manager` in the reserved list, because it is a platform namespace on all clusters.
- B: change the K15 text, so that it does not tell that Terraform creates `cert-manager` on `kind-local`.

No recommendation yet. Step R3 decides, because it adds the `cert-manager` component.
