# Remove a runtime security tool

This guide shows how to remove Tetragon or Falco from a cluster. It also shows how to delete the resources and the files that stay after the removal of the Application.

Remove a tool when one of these occurs:

- A comparison run needs one tool only, or no tool.
- A demonstration with the second tool is complete.
- A cluster must stop the runtime security agents.

When a component leaves `cluster.yaml`, Argo CD deletes its Application but keeps its resources. The reason is in [GitOps with Argo CD](../explanation/gitops-with-argo-cd.md#why-a-removed-component-keeps-its-resources).

## Before you start

- The kubeconfig context is the context of the cluster, for example `kind-kind-local`.
- A local clone of `main`, with the merge of the removal.

## Remove the tool from the cluster

1. Remove the item of the tool from `gitops/clusters/<cluster>/cluster.yaml`.
2. Remove `gitops/clusters/<cluster>/values/<tool>.yaml` if it exists. On `kind-local`, `values/tetragon.yaml` exists.
3. Render the manifests:

   ```bash
   mise run manifests:render
   ```

4. Merge the change. Refer to [Make a change](make-a-change.md).
5. Make sure that Argo CD deleted the Application:

   ```bash
   kubectl -n argocd get application <tool>
   ```

   The output is `NotFound`.

## Delete the resources of the tool

The resources stay in the cluster after the removal of the Application. Delete them from the rendered files of the last commit that has them.

1. Pull `main`:

   ```bash
   git switch main && git pull
   ```

2. Delete the resources of the rendered files before the removal. Set `tool` and `cluster` first:

   ```bash
   tool=tetragon
   cluster=kind-local
   dir="gitops/clusters/${cluster}/rendered/${tool}"
   rev="$(git rev-list -1 HEAD -- "${dir}")^"
   git ls-tree -r --name-only "${rev}" -- "${dir}" \
     | while read -r file; do git show "${rev}:${file}"; printf '\n---\n'; done \
     | kubectl delete --ignore-not-found -f -
   ```

3. Make sure that the Namespace of the tool is gone:

   ```bash
   kubectl get namespace <tool>
   ```

   The output is `NotFound`.

4. For Tetragon, make sure that the three CRDs are gone:

   ```bash
   kubectl get crd tracingpolicies.cilium.io tracingpoliciesnamespaced.cilium.io podinfo.cilium.io
   ```

   The output is `NotFound` for each CRD. The deletion of the CRDs also deletes each `TracingPolicy` and `TracingPolicyNamespaced` object.

## Remove the Tetragon files from the nodes

Tetragon keeps files on each node after the deletion of its pods: its BPF pins, its run folder and its logs. Falco needs no clean-up on the nodes.

1. Make sure that no Tetragon pod runs:

   ```bash
   kubectl get pods -A -l app.kubernetes.io/name=tetragon
   ```

2. On `kind-local`, remove the files from each node:

   ```bash
   for node in kind-local-control-plane kind-local-worker; do
     docker exec "${node}" rm -rf /sys/fs/bpf/tetragon /var/run/tetragon /var/log/tetragon
   done
   ```

3. Make sure that the files are gone:

   ```bash
   for node in kind-local-control-plane kind-local-worker; do
     docker exec "${node}" ls /sys/fs/bpf /var/run /var/log
   done
   ```

   The output has no `tetragon` entry.

`/var/log/tetragon` can be large, for example 59 MiB on a worker node after load runs. `/sys/fs/bpf/cilium` and `/sys/fs/bpf/tc` belong to Cilium. Do not remove them.

A new `kind-local`, from `instance:down` and `instance:up`, has new nodes with none of these files.

## Related pages

- [Runtime security components](../reference/runtime-security-components.md)
- [Add a GitOps component](add-a-gitops-component.md#remove-a-component)
- [Run the runtime security attack set](run-the-runtime-security-attack-set.md)
- [Runtime security with Tetragon and Falco](../explanation/runtime-security-with-tetragon-and-falco.md)
