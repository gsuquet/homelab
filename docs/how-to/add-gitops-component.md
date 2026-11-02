# Add a GitOps component

This guide shows how to add an infrastructure component or an application to a cluster. Argo CD then deploys it from Git.

## Before you start

- Argo CD runs on the cluster. The `bootstrap-argocd` module installs it.
- You ran `mise install`.

## Add a component

1. Make the folder `gitops/infrastructure/<component>/`. For an application, use `gitops/apps/<app>/`. Use `infrastructure/` when the component must change cluster-scoped resources, for example CRDs or webhooks.
2. Add `sources/Chart.yaml`. Set the upstream chart as a dependency with an exact version.
3. Add `sources/values.yaml` with the values for all clusters.
4. Add `sources/templates/namespace.yaml`. Argo CD does not create namespaces. Use the restricted level if the pods comply:

   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: <namespace>
     labels:
       pod-security.kubernetes.io/enforce: restricted
       pod-security.kubernetes.io/audit: restricted
       pod-security.kubernetes.io/warn: restricted
       tenant.infra.gsuquet.com/name: platform   # The tenant of an apps component is not platform.
       ownership.infra.gsuquet.com/owner: gsuquet
       app.kubernetes.io/name: <component>
       app.kubernetes.io/instance: <component>
       app.kubernetes.io/managed-by: Helm
     annotations:
       argocd.argoproj.io/sync-wave: "-2"
   ```

   The Namespace needs these labels. For an `infrastructure` component, the tenant is `platform`. For an `apps` component, use the tenant of the component in `policy/data/labels.yaml`. Refer to [Labels and annotations](../reference/labels-and-annotations.md#required-keys).

5. If the chart has CRDs, give them the annotation `argocd.argoproj.io/sync-wave: "-1"` with a value of the chart. Most charts have a value for CRD annotations. Helm does not template the files in the `crds/` folder of a chart. Thus these CRDs get no annotation, and the Conftest policy rejects them. If the chart has a value that renders its CRDs from `templates/`, set it. Else, do not add the chart.
6. Give each container a memory request equal to its memory limit, and a CPU request. Do not set a CPU limit.
7. Add the component to `gitops/clusters/<cluster>/cluster.yaml`. Use the list of the group: `infrastructure` or `apps`. Add `dependsOn` if the component needs another component first, for example its CRDs:

   ```yaml
   apps:
     - name: <component>
       namespace: <namespace>
       dependsOn:
         - cert-manager
   ```

8. Optional: add `gitops/clusters/<cluster>/values/<component>.yaml` with the values for this cluster only.
9. Run `mise run manifests:render`.
10. Make sure that `gitops/clusters/<cluster>/rendered/<component>/` contains the expected manifests, and that `rendered/argocd/` contains the new Application.
11. Run `mise run lint` and `mise run schemas:check`.
12. Open a pull request. Do not push to `main`.

When the pull request merges, the `argocd` Application makes the new Application in its sync wave. Argo CD then syncs the component.

## Remove a component

1. Remove the component from `gitops/clusters/<cluster>/cluster.yaml`.
2. Remove `gitops/clusters/<cluster>/values/<component>.yaml` if it exists.
3. Run `mise run manifests:render`.
4. Open a pull request.

When the pull request merges, Argo CD deletes the Application. The Application has no resources finalizer, thus the resources stay in the cluster. Delete them with `kubectl` if necessary.

## Related pages

- [GitOps layout](../reference/gitops-layout.md): the fields of `cluster.yaml`, the values order and the sync waves.
- [Labels and annotations](../reference/labels-and-annotations.md#required-keys): the required labels.
- [GitOps with Argo CD](../explanation/gitops-with-argocd.md): why each component ships its Namespace, and why a removed component keeps its resources.
- [Render manifests](render-manifests.md)
