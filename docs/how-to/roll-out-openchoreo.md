# Roll out OpenChoreo

This guide installs OpenChoreo v1.3.3 on `kind-local` (milestone M2), in steps R1 to R7, and rolls it back. The reasons are in [OpenChoreo platform](../explanation/openchoreo-platform.md). The specs, the done criteria and the open checks are in [OpenChoreo platform (reference)](../reference/openchoreo-platform.md).

## Before you start

- Use the 16 GB laptop. The 8 GB laptop cannot run M2.
- Give the Docker VM 12 GiB of memory or more.
- Merge the doc PR of this design first. Each step is one PR.
- Do the steps in order. Each step needs the previous step.

## Stop rules

- Stop at each failed check. Add `state/needs-decision` to the PR, and set the Status to `Final review`.
- Do not start R2 before External Secrets Operator works (R1).
- If kgateway refuses Gateway API v1.6.2 in R3, stop. The Gateway API version is then decided again.
- Do not start R6 before the tenants design ([issue #182](https://github.com/gsuquet/homelab/issues/182)) merges.
- If the repository agent role fails its tests, M2 is not done. Stop, and wait for a decision.
- Do not add a second tenant before the repository agent role works.
- Do not install OpenChoreo on `olympus` or in the cloud before the repository agent role works.

## Steps

### R1 Dependency

1. Wait until the secrets design delivers External Secrets Operator. Refer to [Secrets management](../explanation/secrets-management.md).
2. In each later PR that adds a consumer component, add its consumer entry in the same PR.
3. Render the ServiceAccount `eso-seed-reader` and the store `secrets` of each consumer from the secrets template. Refer to [Add a secret consumer](add-a-secret-consumer.md).
4. After each PR that adds a seed, run `mise run secrets:apply kind-local`. Refer to [Apply secrets](apply-secrets.md).

### R2 Terraform

1. In the `cluster-kind` or `bootstrap-cilium` module, read the subnet of the `kind` Docker network.
2. Make one `CiliumLoadBalancerIPPool` from that subnet. Keep L2 announcements off.
3. Add the CoreDNS `rewrite` for the OpenChoreo hostnames to the `coredns` ConfigMap in `kube-system`.

### R3 cert-manager, kgateway and ThunderID

1. Add the `cert-manager` component, chart v1.21.2, namespace `cert-manager`.
2. Add the `kgateway` component, v2.3.11, namespace `kgateway-system`.
3. Add the `thunder` component, namespace `thunder`.
4. Add `thunder` to the consumer list, with its seeds, its `eso-seed-reader` and its store `secrets`.
5. Seed no ThunderID sample users with fixed passwords.

Checks:

- kgateway accepts the Gateway API v1.6.2 CRDs of Terraform.
- The kgateway charts install no Gateway API CRDs.
- Each Gateway becomes `Programmed` with an address from the LB IPAM pool.

### R4 Control plane

1. Add the `openchoreo-control-plane` component, chart 1.3.3.
2. Add the CA `ClusterIssuer` and the cluster-scoped platform definitions.
3. Add the admission policy for the cell namespaces.
4. Add the Conftest check for the `ClusterProjectType` labels.
5. Add the Conftest check for `property: value`.
6. Add `openchoreo-control-plane` to the consumer list, with its seeds, `eso-seed-reader` and store `secrets`.
7. Keep `remoteConnect.enabled: false` and `features.secretManagement.enabled` off.

Check: the 36 CRDs apply with `ServerSideApply=true` and `Prune=false`.

### R5 Data plane

1. Add the `openchoreo-data-plane` component, chart 1.3.3.
2. Add the `ClusterDataPlane` `default` with `openchoreo.dev/networkpolicyprovider: cilium`.
3. Use the upstream agent role for the first sync.
4. Change the `apps` AppProject once, for this design and for [kagent and agentgateway](../reference/kagent-and-agentgateway.md):
   - Add the blacklist of the platform kinds.
   - Add the blacklist of the `external-secrets.io`, `agentgateway.dev` and `kagent.dev` groups.
   - Add the `Namespace` name blacklist.
   - Render the destinations from `cluster.yaml`.
5. Add the second admission policy, for the writes of the cluster agent.
6. Before the end of M2, open a later PR that changes to the repository agent role.

Check: `kubectl get clusterdataplane default -o jsonpath='{.status.agentConnection.connected}'` returns `true`.

### R6 Sample tenant

1. Use the tenant layout of the tenants design.
2. As the platform, add the OpenChoreo namespace `sandbox`, its Environments and its DeploymentPipeline.
3. As the tenant, add the sample `go-greeter-service`.
4. In the same PR, add the store `oc-sandbox`, the namespace `secret-seeds-oc-sandbox` and the test seed.
5. Run `mise run secrets:apply kind-local`.

Check: all [done criteria](../reference/openchoreo-platform.md#done-criteria-for-m2) pass.

### R7 Documentation

1. Add a how-to page for an OpenChoreo component.
2. Add a reference page for the namespaces.

## Roll back

On `kind-local`, the only supported rollback is a new cluster from the commit before the change:

1. Run `mise run instance:down`.
2. Check out the commit before the change.
3. Run `mise run instance:up kind-local`.

The Git path below is best effort.

### Go back to the default network policy provider

1. Remove the annotation `openchoreo.dev/networkpolicyprovider` from the `ClusterDataPlane`.
2. Check that the controller renders standard `NetworkPolicy` objects.
3. Check that the old `CiliumNetworkPolicy` objects go away.

### Remove OpenChoreo through Git

A removal from `cluster.yaml` alone deletes nothing in the cluster. The `Application` template has no resources finalizer. The OpenChoreo kinds have controller finalizers, for example `openchoreo.dev/releasebinding-cleanup`. Only the running controller removes them. The webhooks refuse each update while the controller is down, also the removal of a finalizer. `selfHeal` makes again each object that Git still holds. Thus do the steps in this order:

1. Remove the tenant component from `cluster.yaml`. Argo CD deletes the `Application` and leaves its objects.
2. While the controller runs, delete the tenant `ReleaseBinding`, `ProjectReleaseBinding`, `Component`, `Project` and `Environment` objects.
3. Wait until the `dp-*` namespaces are gone.
4. While the controller runs, remove the data plane component from `cluster.yaml`.
5. Delete the `ClusterDataPlane`, and wait until its finalizer is gone.
6. Delete the agent `Deployment`, the agent `ClusterRole` and `ClusterRoleBinding`, and the `openchoreo-data-plane` namespace.
7. Remove the control plane component from `cluster.yaml`. Argo CD leaves its objects, thus `selfHeal` cannot make the webhooks again.
8. Delete the validating and mutating webhook configurations of OpenChoreo.
9. Delete the controller, the other control plane objects and the namespace.
10. If an object stays, remove its finalizers by hand. The webhooks are gone, thus the update succeeds.
11. Delete the `openchoreo.dev` CRDs.
12. If necessary, remove ThunderID, kgateway and cert-manager in the same way.
