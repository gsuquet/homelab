# Explanation: Architecture

This document describes the overall architecture of the homelab — what each layer does, why it was chosen, and how the components relate to each other.

---

## Overview

This repository serves as a learning sandbox and central configuration archive for Infrastructure as Code and GitOps practices. The primary live deployment target described below is a single-node K3s cluster on a Raspberry Pi (`olympus.local`), alongside local development targets (e.g. `Kind`). Every piece of infrastructure is declared in Git and applied automatically.

```ascii
┌─────────────────────────────────────────────────────────────┐
│                     GitHub (gsuquet/homelab)                 │
│  ansible/  │  kubernetes/bootstrap/  │  kubernetes/applications/  │
└──────┬──────────────────┬─────────────────────┬─────────────┘
       │                  │                     │
       │ (provision)      │ (self-manage)        │ (sync)
       ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      olympus.local                          │
│                                                             │
│  ┌──────────────┐   ┌───────────────────────────────────┐  │
│  │   K3S        │   │  ArgoCD                           │  │
│  │  v1.34.1     │   │  (watches Git, syncs cluster)     │  │
│  └──────────────┘   └───────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Applications (namespace: homeassistant)            │   │
│  │  Home Assistant │ Mosquitto │ Zigbee2MQTT           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Applications (namespace: actualbudget)             │   │
│  │  ActualBudget                                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  System (various namespaces)                        │   │
│  │  Sealed Secrets Controller │ cloudflared            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
       ▲
       │ (Zigbee TCP serial)
┌──────────────┐
│  Zigbee      │
│  Coordinator │
│  192.168.1.28│
└──────────────┘
```

---

## Why K3S

[K3S](https://k3s.io/) is a lightweight, certified Kubernetes distribution designed for resource-constrained environments. It packages everything into a single binary under 100 MB, uses SQLite instead of etcd by default, and starts in seconds.

For a single-node homelab running on hardware with limited RAM, K3S provides full Kubernetes compatibility without the overhead of a production-grade distribution. It runs standard workloads, supports Helm, and integrates with all Kubernetes tooling.

---

## The Node: olympus.local

The cluster is a single node named `olympus.local`. It runs all control-plane components and all workloads simultaneously. The node is accessed via SSH as the `daedalus` user.

Key networking parameters:

- **Cluster CIDR** (pod network): `10.42.0.0/16`
- **Service CIDR**: `10.43.0.0/16`
- **API server port**: 6443
- **TLS SAN**: `olympus.local` (included in the server certificate)

The firewall (`ufw`) allows SSH only from the local network (`192.168.1.0/24`) and opens only the ports required for K3S operation.

---

## Provisioning with Ansible

Ansible provisions the bare-metal node before any Kubernetes workloads run. The `ansible/playbooks/install.yml` playbook applies six plays in sequence:

1. **Raspberry Pi prerequisites** — enables Linux cgroups in the bootloader (required for Kubernetes)
2. **OS hardening** — UFW firewall, fail2ban, SSH key-only authentication
3. **K3S common** — kernel networking (IP forwarding, netfilter), firewall rules for the cluster network
4. **K3S server** — downloads and installs K3S, writes the systemd service, copies kubeconfig
5. **K3S agent** — (skipped unless agent hosts are defined in inventory)
6. **ArgoCD bootstrap** — applies pre-rendered ArgoCD manifests and the bootstrap Application

After Ansible completes, the cluster is self-managing: ArgoCD watches the Git repository and reconciles any drift.

---

## Declarative App Management with ArgoCD

ArgoCD is the single reconciliation loop that keeps the cluster in sync with the Git repository. It polls the repo every 3 minutes and applies any changes it finds.

Applications are organised into two projects:

- **`system`**: Platform infrastructure (`sealed-secrets`, `cloudflare`) — allowed to create cluster-scoped resources
- **`applications`**: User-facing services (`homeassistant`, `mosquitto`, etc.) — namespace-scoped only

Two `ApplicationSet` resources use the Git directory generator to auto-discover apps:

```text
kubernetes/applications/<name>/  →  ArgoCD Application: <name>
kubernetes/system/<name>/        →  ArgoCD Application: <name>
```

Adding a new directory under `kubernetes/applications/` automatically triggers ArgoCD to create and deploy a new Application — no ArgoCD configuration changes required.

---

## Network Topology

```text
Internet
    │
    ▼
Cloudflare Edge (HTTPS termination)
    │
    │ (encrypted tunnel)
    ▼
cloudflared pod (namespace: cloudflare)
    │
    │ (in-cluster HTTP)
    ▼
Application Service (ClusterIP)
    │
    ▼
Application Pod
```

- External access is provided by Cloudflare Tunnels via the `cloudflared` deployment
- No ports are opened on the home router
- DNS records are managed in the Cloudflare dashboard
- Internal service-to-service communication uses Kubernetes DNS (`<service>.<namespace>.svc.cluster.local`)

---

## Secret Management

Plain Kubernetes `Secret` objects cannot be committed to Git (they are only base64-encoded). [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) encrypts secrets with the cluster's RSA public key. The encrypted `SealedSecret` objects are safe to commit and are decrypted only by the Sealed Secrets controller running in the cluster.

See [Secret Management](secret-management.md) for details.
