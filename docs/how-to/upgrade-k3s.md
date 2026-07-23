# How to Upgrade K3S

K3S upgrades are performed by updating the version variable in the inventory and running the upgrade playbook. The playbook upgrades nodes one at a time (`serial: 1`) to minimise disruption.

---

## 1. Find the New Version

Check the [K3S releases page](https://github.com/k3s-io/k3s/releases) for the latest stable version. Version strings follow the pattern `v<major>.<minor>.<patch>+k3s<n>`, for example `v1.34.1+k3s1`.

---

## 2. Update the Version Variable

Open `ansible/inventory/group_vars/all.yml` and update `k3s_version`:

```yaml
k3s_version: v1.34.2+k3s1   # updated from v1.34.1+k3s1
```

---

## 3. Run the Upgrade Playbook

From the `ansible/` directory:

```bash
cd ansible
ansible-playbook playbooks/upgrade.yml
```

The playbook runs two plays:

1. **Upgrade K3s Servers** (`serial: 1`) — upgrades control-plane nodes one at a time
2. **Upgrade K3s Agents** (`serial: 1`) — upgrades worker nodes one at a time

Each node is upgraded by:

1. Checking the currently installed version
2. Skipping if already at or above the target version
3. Backing up the current K3S service files
4. Running the K3S install script with the new version
5. Restoring service files and restarting the service

---

## 4. Verify the Upgrade

```bash
kubectl get nodes
```

The `VERSION` column should reflect the new K3S version for all nodes:

```bash
NAME           STATUS   ROLES                  AGE   VERSION
olympus.local  Ready    control-plane,master   10d   v1.34.2+k3s1
```

Also verify that ArgoCD and all applications are still healthy after the upgrade:

```bash
kubectl get applications -n argocd
```
