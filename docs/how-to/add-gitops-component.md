# Add a GitOps component

This procedure adds an infrastructure component or an application to a cluster. Argo CD then deploys it from Git. For the design, refer to [GitOps with Argo CD](../explanation/gitops-with-argocd.md).

## Prerequisites

- Argo CD runs on the cluster. The `bootstrap-argocd` module installs it.
- You ran `mise install`.

## Procedure

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
     annotations:
       argocd.argoproj.io/sync-wave: "-2"
   ```

5. If the chart has CRDs, give them the annotation `argocd.argoproj.io/sync-wave: "-1"`. Most charts have a value for CRD annotations. Helm cannot change the files in the `crds/` folder of a chart. If the chart has CRDs only there, ask for a review of the render task before you add the component.
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
12. Open a pull request.

When the pull request merges, the `argocd` Application makes the new Application in its sync wave. Argo CD then syncs the component.

## Remove a component

1. Remove the component from `gitops/clusters/<cluster>/cluster.yaml`.
2. Remove `gitops/clusters/<cluster>/values/<component>.yaml` if it exists.
3. Run `mise run manifests:render`.

Argo CD deletes the Application. The Application has no resources finalizer, thus the resources stay in the cluster. Delete them with `kubectl` if necessary.
