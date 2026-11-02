# Why the platform runs on a local cluster first

The modules and the platform of this repository get their first test on `kind-local`. `kind-local` is a Kind cluster on a laptop: its Kubernetes nodes are Docker containers. This page discusses why the repository gives this cluster that role, and what the role costs.

## A place where a mistake is cheap

The repository manages real systems. The Raspberry Pi `olympus` runs the smart home, and the repository also manages provider accounts: Cloudflare, AWS, Google Cloud, Azure and Grafana Cloud. A wrong change there can stop the smart home, change DNS, or start a charge above a free limit.

A Kind cluster has none of these risks. It lives on one laptop, it reaches no account, and `mise run instance:down kind-local` removes it with all its contents. Thus the first test of a new idea is safe. A spike is a throwaway experiment that answers one open question. It always stays on `kind-local`, because there it cannot change the homelab or a cloud account. For the same reason, a change to `kind-local` itself is a small, reversible change. It does not need the doc-first step of [How we work](how-we-work.md).

The rules in `instance.yaml` show this low risk. `kind-local` has the purpose `test`, so `instance:up` and `instance:down` apply with no approval question. Its Terraform state stays on the laptop, because the cluster lives there too. The schema refuses local state for a `production` or a `demo` instance.

## The same path as every other cluster

A local cluster is only useful if it tests the real thing. `kind-local` is not a special setup with its own scripts. It is an instance like the others, with the same parts:

- `instances/kind-local/` calls the shared Terraform modules in `modules/`, in the layers that `instance.yaml` lists.
- `gitops/clusters/kind-local/` lists the components that Argo CD syncs, and holds their rendered manifests.
- `mise run instance:up` and `instance:down` are the same tasks for each instance.

Terraform installs Argo CD one time, from the same rendered manifests that Argo CD then syncs from Git. After that, Argo CD manages itself and the components of the cluster. When this works on `kind-local`, the modules, the GitOps tree and the tasks have all run together, in the order that a real cluster uses. [Repository structure](repository-structure.md) tells how the instance and the GitOps cluster connect through their name.

This is also why the repository has no `examples/` folder for its modules. `kind-local` calls the modules, and the tests run on it, so it is the working example. The cost is that a reader must find the instance that calls a module, instead of an example next to the module.

## A rehearsal for risky changes

Some changes cannot be undone on the live system. For these, `kind-local` is the rehearsal. The rename of the repository is an example. [Rename the repository](../how-to/rename-the-repository.md) starts with a rehearsal of the Argo CD safety settings on `kind-local`. The rehearsal uses the Argo CD version of `olympus`, and it occurs before any step on `olympus`.

A branch can also run on `kind-local` before it merges. The Argo CD Applications sync `main`, but a values file in `gitops/clusters/kind-local/values/` can point them to a branch. [GitOps with Argo CD](gitops-with-argocd.md#test-a-branch-on-kind) tells how.

## What Kind does not show

A Kind cluster is not the same as a cluster on hardware or in a cloud. `kind-local` needs some settings that exist only for Kind:

- The `cluster-kind` module turns off the default network plugin of Kind, so that Cilium can be the network plugin.
- The `bootstrap-cilium` module gets `cluster_type = "kind"`, and the address of the Kind control plane container as the API server address.
- The `cluster-kind` module has a workaround for the Cilium Bandwidth Manager in Kind nodes.

A test on `kind-local` does not cover these settings for another cluster. The laptop also sets limits that a real cluster does not have. The Docker VM needs at least 4 GiB of memory, else the control plane fails during the apply. Behind a company proxy that inspects TLS, the Kind nodes must trust the proxy CA before they can pull images. [Resize the Colima VM](../how-to/resize-the-colima-vm.md) and [Use Kind behind a TLS-inspecting proxy](../how-to/use-kind-behind-a-tls-proxy.md) cover these two cases.

Thus a pass on `kind-local` is the first check, not the last. It shows that the modules, the GitOps tree and the tasks work together. It does not show that a specific cluster, with its own hardware and network, works.

## Related pages

- [Run your first local cluster](../tutorials/run-your-first-local-cluster.md)
- [Instance tasks](../reference/instance-tasks.md)
- [How we work](how-we-work.md)
- [Repository scope](repository-scope.md)
