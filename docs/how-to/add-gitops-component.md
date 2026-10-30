# Add a GitOps component

This procedure adds a platform component or an application to an instance. Argo CD then deploys it from Git. For the design, refer to [GitOps with Argo CD](../explanation/gitops-with-argocd.md).

## Prerequisites

- Argo CD runs on the instance. The `bootstrap-argocd` module installs it.
- You ran `mise install`.

## Procedure

1. Make the folder `gitops/platform/<component>/`. For an application, use `gitops/apps/<app>/`.
2. Add `sources/Chart.yaml`. Set the upstream chart as a dependency with an exact version.
3. Add `sources/values.yaml` with the values for all instances.
4. Add `sources/chart.env` with `NAMESPACE=<namespace>`.
5. Add `sources/templates/namespace.yaml`. Argo CD does not create namespaces. Use the restricted level if the pods comply:

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

6. If the chart has CRDs, give them the annotation `argocd.argoproj.io/sync-wave: "-1"`. Most charts have a value for CRD annotations. Helm cannot change the files in the `crds/` folder of a chart. If the chart has CRDs only there, ask for a review of the render task before you add the component.
7. Give each container a memory request equal to its memory limit, and a CPU request. Do not set a CPU limit.
8. Add `values/<instance>.yaml` for each instance that uses the component. The file can be empty.
9. Run `mise run manifests:render`.
10. Make sure that `rendered/<instance>/` contains the expected manifests.
11. Add the component to `gitops/instances/<instance>.yaml`:

    ```yaml
    platform:
      - name: <component>
        namespace: <namespace>
    ```

12. Run `mise run lint` and `mise run schemas:check`.
13. Open a pull request.

When the pull request merges, the ApplicationSet makes the Application. Argo CD then syncs the component.

## Remove a component

1. Remove the component from `gitops/instances/<instance>.yaml`.
2. Remove `values/<instance>.yaml` from the component, then run `mise run manifests:render`.

The ApplicationSet deletes the Application. The ApplicationSet has `preserveResourcesOnDeletion: true`, thus the resources stay in the cluster. Delete them with `kubectl` if necessary.
