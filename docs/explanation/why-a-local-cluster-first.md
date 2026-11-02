# Why the platform runs on a local cluster first

The platform has two kinds of targets. At home, a Talos cluster runs on the Raspberry Pi nodes, which are arm64. In the cloud, demo and long-lived instances run on GKE or AKS. A change to the platform must work on both. A test on these targets is slow, and a mistake there has a real effect.

Thus each change gets its first test on a laptop, on `kind-local`. The local cluster must be fast, so that the loop of change and test stays short. It must also be close enough to the targets that a change that works locally also works there. This page tells why Kind meets these two needs, where it stops, and why the other local tools do not do better.

## Why Kind

`kind-local` is a Kind cluster on Colima. Kind runs each Kubernetes node as a Docker container. A cluster with two nodes starts or stops in about a minute. `mise run instance:down kind-local` removes it with all its contents, so a failed test leaves nothing behind.

Kind runs plain upstream Kubernetes, set up with kubeadm. The managed clusters of GKE and AKS also run upstream Kubernetes. Thus the platform layer behaves the same on `kind-local` as on a cloud cluster. Examples of this layer are Cilium, the Gateway API, cert-manager and Argo CD.

Kind also has the CPU architecture of the home target. The laptop is arm64, so the Kind nodes are `linux/arm64`, the same as the Pi nodes. An image that has no arm64 build fails on `kind-local` before it fails at home.

Kind fits the tools of the repository. The `cluster-kind` module creates the cluster through the `tehcyx/kind` Terraform provider, and the `instance:*` tasks drive it like any other instance. `kind-local` is not a special setup with its own scripts. It uses the same modules, the same GitOps tree and the same tasks as the other instances.

The low risk also makes `kind-local` the place for experiments. A spike, a throwaway experiment that answers one open question, always stays on `kind-local`, because there it cannot change the homelab or a cloud account. A risky change to a live system, for example the rename of the repository, starts with a rehearsal on `kind-local`.

## What Kind does not reproduce

Kind is close to the targets, but it is not the same as them.

A Kind node is a container, so it shares the kernel of the Colima VM. Some kernel settings that Cilium expects do not exist in that kernel. The `cluster-kind` module has a workaround for this gap. Its `kind_bpf_sysctls` resource installs a service in each node. The service mounts a fake `/proc/sys/net/core`, with the values that the Cilium Bandwidth Manager reads. A real node has the real kernel and needs no such workaround. `kind-local` also needs settings that exist only for Kind, for example `cluster_type = "kind"` for Cilium. A test on `kind-local` does not cover these settings for another cluster.

Kind does not run Talos. The Talos machine config, the Talos upgrade flow, the read-only OS and the Talos settings for Cilium do not exist on `kind-local`. The plans include a second local instance, `talos-local`, to rehearse this Talos-only behavior.

Kind does not run a cloud either. Managed load balancers, cloud IAM, storage classes and autoscaling exist only on GKE or AKS. A cloud instance tests them, not the laptop.

Thus a pass on `kind-local` is the first check, not the last. It shows that the modules, the GitOps tree and the platform layer work together. It shows this on upstream Kubernetes and on arm64. It does not show that the Talos or the cloud specifics work.

## Alternatives

Other tools also run Kubernetes on a laptop. None of them is a better match for these targets.

- **k3d** runs k3s in Docker. k3s bundles its own components: Traefik, flannel and kine in place of etcd. These move the local cluster away from both Talos and GKE or AKS. k3d is useful only for a k3s target, and the targets do not run k3s.
- **minikube** usually runs one node, and it is slower than Kind. It gives no gain for these targets.
- **Talos in Docker** is the best match for the home target. But it is slower than Kind, and it gives no gain for GKE or AKS. It also needs `talosctl` in place of a Terraform provider that creates clusters. Thus it does not replace Kind as the default.

## Related pages

- [Run your first local cluster](../tutorials/run-your-first-local-cluster.md)
- [Instance tasks](../reference/instance-tasks.md)
- [How we work](how-we-work.md)
- [Repository structure](repository-structure.md)
