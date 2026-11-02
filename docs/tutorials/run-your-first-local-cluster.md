# Run your first local cluster

In this tutorial, we start a Kubernetes cluster on our computer with one command. We open Argo CD in a browser and watch it repair a resource that we delete. Then we remove the cluster.

## Before we start

We need:

- a Mac or a Linux computer with at least 8 GiB of memory;
- [mise](https://mise.jdx.dev/), activated in our shell;
- the `docker` command and [Colima](https://github.com/abiosoft/colima), installed but not started;
- `kubectl`;
- a clone of the repository:

  ```bash
  git clone https://github.com/gsuquet/homelab.git
  cd homelab
  ```

We type all the commands in this tutorial in the `homelab` folder.

## Install the tools

First, we install the tools of the repository:

```bash
mise install
```

mise reads `.mise/config.toml` and installs each tool at the version that the file gives. This includes Terraform and kind.

Let's check that Terraform is there:

```bash
terraform version
```

The first line of the output looks like this:

```text
Terraform v1.17.0
```

## Start the cluster

Now we start the cluster. The instance name is `kind-local`:

```bash
mise run instance:up kind-local
```

The task starts Colima, then Terraform creates the cluster and installs Argo CD. This takes some minutes. The output starts like this:

```text
[INFO] Starting Colima...
```

Terraform then prints its plan and its changes. Notice the two `Apply complete!` lines: the task applies the cluster first, and then everything else. The output ends like this:

```text
Outputs:

cilium_release_status = "deployed"
cluster_name = "kind-local"
gateway_api_channel = "standard"
kubeconfig_path = "/Users/<name>/.kube/kind-kind-local"
[INFO] Adding the kubeconfig context kind-kind-local...
Set kubectl context to "kind-kind-local"
[INFO] ✓ Instance is up: kind-local
```

The last line tells us that the cluster is ready. The task also made `kind-kind-local` our current kubectl context, so kubectl now talks to our new cluster.

Let's look at the nodes:

```bash
kubectl get nodes
```

We see two nodes, and each one is `Ready`:

```text
NAME                       STATUS   ROLES           AGE   VERSION
kind-local-control-plane   Ready    control-plane   3m    v1.x.y
kind-local-worker          Ready    <none>          3m    v1.x.y
```

## Open Argo CD

Argo CD runs in the cluster. First, we get the password of its `admin` user:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

The command prints a random password. We copy it.

Now we open a tunnel from our computer to the Argo CD server:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

The command prints `Forwarding from 127.0.0.1:8080 -> 8080` and keeps running. We leave this terminal open, and we open a second terminal in the `homelab` folder.

In a browser, we open <http://localhost:8080>. We log in as `admin` with the password that we copied.

We see one Application, `argocd`. Its status is `Healthy` and `Synced`. This is Argo CD itself: it reads its own manifests from the `main` branch on GitHub and keeps the cluster equal to them.

## Watch Argo CD repair the cluster

Now we make the cluster different from Git. In the second terminal, we delete one Service that Argo CD manages:

```bash
kubectl -n argocd delete service argocd-server-metrics
```

In the browser, we click the `argocd` Application. For a short time, the Application shows `OutOfSync`. Then Argo CD creates the Service again, and the status goes back to `Synced`.

Let's check it with kubectl:

```bash
kubectl -n argocd get service argocd-server-metrics
```

The Service is back, with a new `AGE`:

```text
NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
argocd-server-metrics   ClusterIP   10.96.x.y      <none>        8083/TCP   20s
```

We did not run a command to restore it. Git is the source of truth, and Argo CD put the cluster back in the state that Git describes.

## Remove the cluster

In the first terminal, we stop the tunnel with <kbd>Ctrl</kbd>+<kbd>C</kbd>. Then we remove the cluster:

```bash
mise run instance:down kind-local
```

Terraform destroys the cluster, and the task removes the kubectl context. The output ends like this:

```text
[INFO] Removed the kubeconfig entries kind-kind-local.
[INFO] ✓ Instance is down: kind-local
```

Colima continues to run. To stop it, we type `colima stop`.

## What we did

We built a Kubernetes cluster with Cilium, the Gateway API and Argo CD from one command. We logged in to Argo CD and saw it manage itself from Git. We deleted a resource and watched Argo CD restore it. Then we removed the cluster and its kubectl context.

## Next steps

- [Why the platform runs on a local cluster first](../explanation/why-a-local-cluster-first.md) tells why `kind-local` exists and what it is for.
- [GitOps with Argo CD](../explanation/gitops-with-argocd.md) tells how Argo CD manages the clusters from Git.
- [Instance tasks](../reference/instance-tasks.md) lists everything that `instance:up` and `instance:down` do.
