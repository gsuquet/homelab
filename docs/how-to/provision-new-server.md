# How to Provision a New Server

Use this guide to provision a brand-new node or to reprovision `olympus.local` from scratch (e.g. after a reinstall).

---

## Add a New Server Node

### 1. Update the inventory

Open `ansible/inventory/hosts.yml` and add the new host under the appropriate group.

For an additional K3S server (control-plane):

```yaml
all:
  children:
    k3s_server:
      hosts:
        olympus.local:
        newserver.local:
```

For a K3S agent (worker-only):

```yaml
all:
  children:
    k3s_server:
      hosts:
        olympus.local:
    k3s_agent:
      hosts:
        worker1.local:
```

### 2. Ensure SSH access

```bash
ssh-copy-id daedalus@newserver.local
ssh daedalus@newserver.local
```

### 3. Run the playbook

From the `ansible/` directory:

```bash
cd ansible
ansible-playbook playbooks/install.yml
```

Ansible skips plays that target hosts not in their group, so existing nodes are unaffected unless the plays target all hosts (OS hardening and Raspberry Pi setup run on all hosts).

To limit execution to only the new host:

```bash
ansible-playbook playbooks/install.yml --limit newserver.local
```

### 4. Verify the node joined

```bash
kubectl get nodes
```

The new node should appear with `Ready` status within a minute of the playbook completing.

---

## Reprovision an Existing Node

If you are rebuilding `olympus.local` from a fresh OS install:

1. Ensure the hostname and SSH user in `ansible/inventory/hosts.yml` still match the new OS setup.
2. Re-copy your SSH key if needed: `ssh-copy-id daedalus@olympus.local`
3. Run the full install playbook:

```bash
cd ansible
ansible-playbook playbooks/install.yml
```

After provisioning, re-merge the kubeconfig if it was overwritten:

```bash
export KUBECONFIG=~/.kube/config:~/.kube/config.new
kubectl config view --merge --flatten > ~/.kube/config-merged
mv ~/.kube/config-merged ~/.kube/config
```

ArgoCD will automatically re-sync and restore all application workloads from Git.
