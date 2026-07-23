# Tutorial: Getting Started

This tutorial walks you through provisioning a fresh server into a fully operational homelab — running K3S, with ArgoCD syncing all applications from Git. By the end you will have a working cluster with all applications deployed.

**Time**: ~30 minutes
**Prerequisite knowledge**: Basic Linux command-line, SSH access

---

## Prerequisites

### Hardware and OS

- A server or Raspberry Pi running a Debian-based OS (Ubuntu, Raspberry Pi OS)
- SSH access from your local machine
- The server must be reachable at `olympus.local` (or update the inventory)

### Tools on your local machine

This project uses [mise](https://mise.jdx.dev/) to manage tool versions. Install it first:

```bash
curl https://mise.run | sh
```

Then from the repo root, install all required tools:

```bash
mise install
```

This installs the versions pinned in `.mise/config.toml`:

| Tool | Version |
|------|---------|
| Helm | 4.2.3 |
| Python | 3.14.6 |
| pre-commit | 4.6.0 |
| yq | 4.53.3 |

Ansible is installed as a Python package. After `mise install`, verify it is available:

```bash
ansible --version
```

### SSH key

Copy your public key to the server so Ansible can connect without a password:

```bash
ssh-copy-id daedalus@olympus.local
```

Verify you can connect:

```bash
ssh daedalus@olympus.local
```

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/gsuquet/homelab.git
cd homelab
```

---

## Step 2: Configure the Ansible Inventory

The inventory file is at `ansible/inventory/hosts.yml`. It defines which hosts belong to which groups:

```yaml
all:
  children:
    k3s_server:
      hosts:
        olympus.local
```

If your server has a different hostname or IP address, replace `olympus.local` with the correct value.

Key variables are set in `ansible/inventory/group_vars/all.yml`:

```yaml
ansible_port: 22
ansible_user: daedalus
k3s_version: v1.34.1+k3s1
timezone: Europe/Paris
```

Update `ansible_user` if your server uses a different user account, and set `timezone` to your local timezone.

---

## Step 3: Install the Pre-commit Hooks

Pre-commit hooks enforce code quality and auto-render Helm manifests before each commit:

```bash
pre-commit install
```

---

## Step 4: Run the Ansible Playbook

From the `ansible/` directory, run the install playbook:

```bash
cd ansible
ansible-playbook playbooks/install.yml
```

The playbook runs six sequential plays:

1. **Raspberry Pi prerequisites** — enables cgroups in the bootloader (skipped on non-Pi hardware)
2. **Harden the OS** — installs `fail2ban`, `ufw`, configures SSH hardening
3. **K3S prerequisites** — configures kernel networking (IP forwarding, firewall rules)
4. **Setup K3S server** — downloads K3S, configures and starts the `k3s` service
5. **Setup K3S agent** — (skipped if no agent hosts defined)
6. **Install ArgoCD** — applies the rendered ArgoCD manifests and the bootstrap application

The playbook copies a kubeconfig to `~/.kube/config.new` on your local machine. Merge it into your active kubeconfig:

```bash
export KUBECONFIG=~/.kube/config:~/.kube/config.new
kubectl config view --merge --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config
```

Or simply point `KUBECONFIG` at the new file for now:

```bash
export KUBECONFIG=~/.kube/config.new
```

---

## Step 5: Verify the Cluster

Check that the K3S node is ready:

```bash
kubectl get nodes
```

Expected output:

```bash
NAME           STATUS   ROLES                  AGE   VERSION
olympus.local  Ready    control-plane,master   1m    v1.34.1+k3s1
```

---

## Step 6: Verify ArgoCD is Running

Check that the ArgoCD pods are up:

```bash
kubectl get pods -n argocd
```

All pods should be in `Running` state. The important ones are:

- `argocd-application-controller-0`
- `argocd-applicationset-controller-*`
- `argocd-repo-server-*`
- `argocd-server-*`
- `argocd-redis-*`

---

## Step 7: Verify Applications are Synced

ArgoCD uses an ApplicationSet to discover and deploy every subdirectory under `kubernetes/applications/` and `kubernetes/system/`. Check that all apps are healthy:

```bash
kubectl get applications -n argocd
```

You should see entries for `homeassistant`, `mosquitto`, `zigbee2mqtt`, `actualbudget`, `sealed-secrets`, and `cloudflare`.

Each application should show `Synced` and `Healthy`. If an app shows `Progressing`, wait a minute and re-check — ArgoCD may still be pulling images.

---

## Next Steps

- [Add your first application](02-add-first-application.md) to deploy a new self-hosted service
- Read [Architecture](../explanation/architecture.md) to understand how all the pieces fit together
- Read [GitOps with ArgoCD](../explanation/gitops-with-argocd.md) to understand how deployments work
