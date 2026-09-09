# Chaos Citadel: The Cloud-Native Defense Game

> **Status:** Architecture & Technical Specification  
> **Target Platform:** Kubernetes (`kind-dev-01`, extensible to cloud/GKE)  
> **Core Technologies:** Go (Golang), Cilium CNI, Hubble, Tetragon, Chaos Mesh, Falco, Kubernetes CRDs  
> **Ecosystem Alignment:** [Zero Trust & Chaos Lab](zero-trust-chaos-lab.md)

---

## 1. Executive Summary & Purpose

**Chaos Citadel** is an interactive, participatory multiplayer defense game designed to demonstrate cloud-native resilience, **Cilium eBPF networking, runtime security, and Chaos Engineering** to a cross-functional audience:

- **Developers & DevOps:** Real-time visibility into L3/L4/L7 traffic, zero-code network troubleshooting, automated topology discovery, and resilience against fault injection.
- **Platform & Security Engineers:** Instant Zero-Trust enforcement, kernel-level packet drops, eBPF Host Firewall node hardening, automated pod quarantine, and cryptographic workload identity.
- **Data Engineers:** High-throughput data transfer visualization, wire encryption, and congestion monitoring.
- **Product Owners & Managers:** Direct visual link between platform security/reliability (Citadel HP) and business continuity/revenue (Treasury Gold).

Audience members participate from their smartphones or laptops, taking actions that generate real network packets, trigger dynamic Kubernetes security policies, or unleash infrastructure chaos—while Hubble UI and live event dashboards serve as the real-time "Battlefield Radar" on the presentation display.

---

## 2. Lab Isolation: Production Services vs. Experimental Labs

### The Challenge: Preventing Production Contamination

In `kubernetes/bootstrap/argo-cd/applications-applicationset.yaml`, ArgoCD dynamically watches subdirectories:

```yaml
directories:
  - path: kubernetes/applications/*
```

Because ArgoCD uses a git generator matching `kubernetes/applications/*`, any new folder placed directly inside `kubernetes/applications/` is **automatically discovered and deployed to the production Raspberry Pi cluster (`olympus.local`)**.

### Non-Disruptive Architecture: Introducing `kubernetes/labs/`

Instead of relocating existing production directories (`applications/`, `bootstrap/`, `system/`)—which would invalidate existing tutorials, operational playbooks, and GitOps application paths—we cleanly isolate workshop and demo workloads under a dedicated `kubernetes/labs/` namespace:

```ascii
kubernetes/
├── applications/                # Production smart-home workloads (olympus.local)
│   ├── actualbudget/
│   ├── homeassistant/
│   ├── mosquitto/
│   └── zigbee2mqtt/
├── bootstrap/                   # ArgoCD root bootstrap for Olympus
├── projects/                    # ArgoCD AppProjects (applications, system)
├── system/                      # Core infrastructure (cloudflare, sealed-secrets)
│
└── labs/                        # Experimental, training, and demo workloads (Kind, GKE)
    └── chaos-citadel/           # Chaos Citadel Game
        ├── backend/             # Go microservices & controller
        ├── manifests/           # Deployments, Services, RBAC
        ├── policies/            # Pre-defined CiliumNetworkPolicy templates
        └── README.md            # Lab deployment & presenter guide
```

### GitOps Safety & Cluster Targeting

1. **Zero Production Cross-Contamination:**
   Because production ApplicationSets strictly target `kubernetes/applications/*` and `kubernetes/system/*`, any folder placed under `kubernetes/labs/` is ignored by the production cluster.
2. **Local Workshop Deployment:**
   During local development or live presentations on `kind-dev-01`, workloads in `kubernetes/labs/chaos-citadel/` are deployed directly via `kubectl` / Kustomize or an optional dev-only ArgoCD Application.
3. **No Migration Overhead:**
   Existing documentation, Ansible tasks, and bootstrap manifests remain 100% intact.

---

## 3. Game Concept & Rules

### The Metaphor

The Kubernetes cluster is a medieval fortress defending its Treasury and Castle Foundations against an invading Goblin Horde:

- **The Outer Gate (`outer-gate`):** Public edge ingress facing external traffic.
- **The Market Square (`market-square`):** Commercial microservice handling merchant trade and user transactions.
- **The Treasury Vault (`treasury-vault`):** Crown jewel database storing the kingdom's Gold and state.
- **The Castle Foundations (Kubernetes Nodes):** The physical or virtual hosts. Protected by the **Cilium Host Firewall**.
- **The Royal Trade Route (Egress Gateway):** Secure outbound highway routing merchant shipments to the external **Allied Realm Bank** with a static trusted IP.
- **The Kernel Firewall (Cilium eBPF):** Magical forcefield guarding pod veth interfaces and host NICs at the Linux kernel layer.

```ascii
       [ AUDIENCE: THE RAIDERS ]                [ AUDIENCE: DEFENDERS & MERCHANTS ]
       (Spamming attacks on phones)               (Defending & Trading on phones)
                    │                                            │
                    ▼                                            ▼
         ┌─────────────────────┐                      ┌─────────────────────┐
         │     OUTER GATE      │                      │    MARKET SQUARE    │
         │  (Public Gateway)   │                      │  (Trade Processor)  │
         └──────────┬──────────┘                      └──────────┬──────────┘
                    │                                            │
                    │ ⚔️ Exploit: /vault/v1/loot                 │ 🪙 Trade: /trade
                    ▼                                            ▼
         ┌───────────────────────────────────────────────────────────────────┐
         │                          TREASURY VAULT                           │
         │    HP: [ ████████████████████ ] 100%   Gold: 1,250 🪙             │
         └──────────────────────────────────┬────────────────────────────────┘
                                            │
         ┌──────────────────────────────────┴────────────────────────────────┐
         │                  eBPF KERNEL SHIELDS (Cilium)                     │
         │  • Pod L7 Curfew: Drops unauthorized /vault requests              │
         │  • Host Firewall: Protects Node NICs & Kubelet from sapper tunnel │
         │  • Egress Gateway: Pins outbound trade to static trusted IP       │
         └──────────────────────────────────┬────────────────────────────────┘
                                            │
                                            ▼ (Static SNAT via Gateway Node)
                          [ EXTERNAL ALLIED REALM BANK ]
                          (Only accepts verified Egress IP)
```

---

### Player Factions & Audience Mechanics

When joining via QR code on mobile, players select or are assigned to one of three factions:

#### 1. The Raiders (Chaos / Attackers) — *DevOps & Chaos Mindset*

- **Objective:** Drain Fortress HP to 0% before time expires.
- **Abilities:**
  - 🗡️ **Spawn Goblin (Recon probe):** Sends rapid HTTP requests to `/api/v1/recon`. Cheap, low damage, tests perimeter defense.
  - 🥷 **Send Infiltrator (L7 Exploit):** Sends targeted HTTP requests attempting path traversal: `GET /vault/v1/loot`. Deals **-10 HP** per successful hit!
  - 💣 **Battering Ram (DDoS Flood):** Initiates concurrent TCP connection bursts against port 80/8080 to saturate gateway workers.
  - 🕳️ **Sapper Tunnel (Node Infiltration):** Bypasses pods and attacks the Kubernetes host directly (attempting SSH port 22 or Kubelet port 10250). Deals catastrophic **-25 HP** to Castle Foundations if unblocked!

#### 2. The Royal Engineers (Defenders / SRE / Security) — *Platform & SRE Mindset*

- **Objective:** Maintain Fortress HP > 0% and protect Treasury & Foundations.
- **Abilities (eBPF Spells):**
  - 🛡️ **Shield Spell: Port Firewall (L4):** Applies a `CiliumNetworkPolicy` dropping any connection on non-approved ports (blocks port scans & raw TCP probes).
  - 📜 **Shield Spell: Royal Curfew (L7 Policy):** Enforces Zero-Trust: only `market-square` is permitted to communicate with `treasury-vault`. Any direct `outer-gate -> treasury-vault` packet is rejected at the kernel level.
  - 🏰 **Shield Spell: Fortify Foundations (Host Firewall):** Applies a `CiliumClusterwideNetworkPolicy` with `nodeSelector`. Instantly blocks sapper attacks on node NICs (SSH / Kubelet / host-ports) via eBPF.
  - 🛣️ **Shield Spell: Royal Treaty Route (Egress Gateway):** Deploys a `CiliumEgressGatewayPolicy` routing merchant deposits through a dedicated gateway node with a static egress IP.
  - ⚡ **Shield Spell: eBPF Quarantine:** Automatically isolates any pod tagged with suspicious labels without killing the container.
  - ⚔️ **Shield Spell: In-Kernel Smite (Tetragon Enforcement):** Applies a Tetragon `TracingPolicy` that terminates unauthorized binary execution (e.g. `/bin/sh` or crypto-miners) with an immediate in-kernel `SIGKILL` before userspace processes even start.

#### 3. The Royal Merchants (Business / POs / Data) — *PO & Data Mindset*

- **Objective:** Earn **10,000 Gold** to win the match.
- **Abilities:**
  - 🥖 **Local Trade Caravan:** Sends legitimate `POST /market/v1/trade` transactions. Each successful 200 OK adds **+50 Gold**.
  - 🏦 **Offshore Treasury Deposit (Egress Gateway):** Exports trade profits to the **External Allied Bank**. If the Egress Gateway spell is active, the external bank accepts the static IP and yields a **2x Bonus (+500 Gold)**! If inactive, the external firewall rejects the random node IP.
  - 📦 **Bulk Data Transfer:** Simulates a high-volume ETL pipeline batch. High reward (**+250 Gold**), but consumes network bandwidth—demonstrating Cilium's Bandwidth Manager (BBR & EDT packet pacing).

---

### Win & Loss Conditions

- **Raider Victory:** Fortress HP hits `0%` before Treasury accumulates 10,000 Gold.
- **Kingdom Victory:** Treasury reaches `10,000 Gold` while Fortress HP remains `> 0%`.
- **Match Duration:** 3 to 5 minutes of high-tempo interactive play.

---

## 4. Technical Architecture (Zero Python)

Strictly written in **Go (Golang)** and standard cloud-native tooling. Single static binaries, zero runtime dependencies, minimal memory footprint (<20MB per pod).

### Microservices Stack (All Written in Go)

```ascii
kubernetes/labs/chaos-citadel/
├── backend/
│   ├── cmd/
│   │   ├── controller/      # Game engine, WebSockets, K8s client-go controller
│   │   ├── outer-gate/      # Lightweight HTTP proxy / Ingress emulator
│   │   ├── market/          # Business logic & trade handler
│   │   └── treasury/        # State store & health monitor
│   ├── internal/
│   │   ├── game/            # Game loop, state sync, rules engine
│   │   ├── k8s/             # client-go & Cilium CRD client interactions
│   │   └── web/             # Embedded HTML5/JS mobile assets (embed.FS)
│   ├── go.mod
│   └── go.sum
```

```ascii
[ Audience Mobile Web UI ] ── WebSocket / HTTP ──▶ [ game-controller (Go) ]
                                                           │
                                                           ▼ (K8s API)
                                            [ Dynamic CiliumNetworkPolicy ]
                                                           │
 [ outer-gate (Go) ] ──▶ [ market-square (Go) ] ──▶ [ treasury-vault (Go) ]
```

### Component Details

1. **`game-controller` (Go):**
   - Serves the mobile-friendly web UI using Go's `embed.FS` (single binary).
   - Manages real-time player sessions and state broadcasting via WebSockets.
   - Holds the authoritative game loop (Fortress HP, Treasury Gold, match timer).
   - **Kubernetes Client & RBAC:** Uses `client-go` and Cilium's typed client under a dedicated `ServiceAccount` granted CRUD permissions over `cilium.io` resources (`ciliumnetworkpolicies`, `ciliumclusterwidenetworkpolicies`, `ciliumegressgatewaypolicies`).
   - **Concurrency & Idempotency:** Implements spell cooldowns and idempotent CRD management (e.g. ignoring `AlreadyExists` or using server-side apply) so simultaneous spell casts from multiple defenders do not cause race conditions.
   - **Match Lifecycle & Teardown:** Automatically cleans up dynamically applied Cilium policies and resets game metrics at match conclusion to prepare for consecutive rounds.

2. **`outer-gate` (Go):**
   - Frontline service receiving traffic from the game controller and audience requests.
   - Forwards legitimate trade calls to `market-square`.
   - Attempts direct calls to `treasury-vault` when an infiltrator attack is triggered.

3. **`market-square` (Go):**
   - Validates transactions, records ledger entries, and communicates with `treasury-vault`.

4. **`treasury-vault` (Go):**
   - Maintains the authoritative gold vault balance and health status.
   - Emits alerts when unauthorized requests penetrate the network perimeter.

---

## 5. Cilium eBPF Network Policies (The "Defense Spells")

The "spells" executed by the Royal Engineers are genuine `CiliumNetworkPolicy` manifests applied directly to the Kubernetes API:

### Spell 1: The Royal Curfew (L7 Zero-Trust Isolation)

Prevents any pod except `market-square` from reaching `treasury-vault`, and restricts HTTP verbs:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: spell-royal-curfew
  namespace: chaos-citadel
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: treasury-vault
  ingress:
    - fromEndpoints:
        - matchLabels:
            app.kubernetes.io/name: market-square
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: POST
                path: "/v1/vault/deposit"
```

### What Happens in the Kernel

1. When unshielded: `outer-gate` successfully sends `GET /v1/vault/loot` to `treasury-vault`. HP drops.
2. When `spell-royal-curfew` is active:
   - Cilium compiles the L7 policy into eBPF socket-level programs.
   - Traffic targeting L7 rules is redirected in the kernel via eBPF sockops to Cilium's internal node-level Envoy proxy (**without injecting pod sidecars**).
   - Unauthorized requests from `outer-gate` are **instantly rejected in the kernel/proxy layer** with a `403 Forbidden` or connection reset.
   - **Hubble UI** displays glowing red dropped flows in real time with the verdict `DROPPED (Policy denied)`.

### Spell 2: Fortify the Foundations (Cilium Host Firewall)

Protects the underlying Kubernetes node physical/virtual network interfaces directly from sapper attacks attempting to probe sensitive host ports (e.g. Kubelet API 10250 or simulated node daemons):

> **Prerequisite:** Cilium Host Firewall must be enabled in the Terraform module (`host_firewall_enabled = true`).

```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: spell-fortify-foundations
spec:
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
  ingress:
    # Essential: allow cluster control plane and node-to-node health checks
    - fromEntities:
        - cluster
        - host
      toPorts:
        - ports:
            - port: "6443"
              protocol: TCP
            - port: "4240"     # Cilium health check
              protocol: TCP
        - icmp:
            - type: 8          # Echo request (Ping)
    # Reject raw sapper probes to port 10250 / SSH from non-cluster entities
```

> [!NOTE]
> **Kind Environment Consideration:** Standard Kind nodes do not run an SSH daemon (port 22) out of the box. Sapper probes simulate host attacks by hitting Kubelet (`10250`) or a lightweight daemon deployed with `hostNetwork: true`. Safe rule definitions ensure essential node communication (such as Cilium health probes on port 4240 and ICMP) are never blocked.

**Kernel Effect:** When active, eBPF programs attached to the host's NIC (`eth0`) drop non-whitelisted node packets before the Linux network stack even processes them.

### Spell 3: The Royal Treaty Route (Cilium Egress Gateway)

Routes high-value merchant deposits headed for the external **Allied Realm Bank** through a dedicated gateway node that SNATs the packets with a predictable, static egress IP:

> **Prerequisites:**
> - Cilium Egress Gateway must be enabled in Terraform (`egress_gateway_enabled = true` and `bpf.masquerade = true`).
> - The cluster topology must have at least 2 worker nodes (`worker_count = 2` in `kind-dev-01`) so one node can be labeled `node.kubernetes.io/role: egress-gateway` while merchant pods run on the other worker.

```yaml
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: spell-royal-treaty-route
  namespace: chaos-citadel
spec:
  selectors:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: market-square
  destinationCIDRs:
    - "198.51.100.100/32"    # External Allied Realm Bank IP (or mock service)
  egressGateway:
    nodeSelector:
      matchLabels:
        node.kubernetes.io/role: egress-gateway
    egressIP: "198.51.100.50"
```

**Kernel Effect:** Merchant pods no longer egress with random worker node IPs. Traffic is encapsulated directly to the gateway node, which SNATs it with `198.51.100.50`. The external bank firewall verifies the static IP, accepts the transfer, and awards the **2x Gold Bonus**!

---

## 6. The Presenter Experience & Stage Setup

### Dual-Screen Layout

```ascii
┌──────────────────────────────────────────────┬──────────────────────────────────────────────┐
│                  SCREEN 1                    │                   SCREEN 2                   │
│         Hubble UI ("Battle Radar")           │       Game Scoreboard & Event Ticker         │
│                                              │                                              │
│  [outer-gate] ──(Green)──▶ [market-square]   │   🏰 FORTRESS HP: [ ██████████ ] 82%         │
│        │                                     │   🪙 TREASURY: 4,350 / 10,000 Gold           │
│        └───(RED DROP)───▶ [treasury-vault]   │                                              │
│                                              │   [ QR Code for Audience: http://... ]       │
│  Live flows: 48 pkts/sec                     │   ⚔️ "Alice blocked 84 Goblins via eBPF!"     │
│  Verdict: DROPPED (spell-royal-curfew)       │   💰 "Bob's caravan added 250 Gold!"         │
└──────────────────────────────────────────────┴──────────────────────────────────────────────┘
```

### Flow of the Presentation (15–20 minutes)

1. **Introduction (2 min):** Explain the problem of Kubernetes networking & security blind spots. Introduce the Castle metaphor.
2. **Scan & Join (2 min):** Audience scans the QR code. Factions are assigned.
3. **Round 1 — Peaceful Commerce (3 min):** Merchants click trade; audience watches green flow lines emerge on Hubble UI without any manual logging or sidecars.
4. **Round 2 — The Goblin Siege (4 min):** Raiders smash attack buttons; red flows appear, Treasury HP starts dropping rapidly. Panic ensues.
5. **Round 3 — The eBPF Defense (4 min):** SREs cast the eBPF Curfew spell; big screen Hubble UI shows every goblin packet getting dropped at kernel speed. Treasury stabilizes and reaches 10,000 Gold.
6. **Wrap-up & Debrief (3 min):**
   - Explain how eBPF accomplished this with zero pod sidecars (using kernel-level socket redirection to node proxies for L7) and zero application code changes.
   - Show how the Terraform module automated the entire infrastructure.

---

## 7. Implementation Roadmap

1. **Step 1: Lab Directory Setup:**
   - Scaffold `kubernetes/labs/chaos-citadel/` structure without modifying existing production `kubernetes/applications/` paths.
2. **Step 2: Infrastructure Configuration (`kind-dev-01`):**
   - Update [terraform/kind-dev-01/main.tf](file:///Users/gsuquet/perso/github/homelab/terraform/kind-dev-01/main.tf) to enable `host_firewall_enabled = true`, `egress_gateway_enabled = true`, and set `worker_count = 2` (to separate gateway and workload nodes).
3. **Step 3: Go Microservices & Controller:**
   - Scaffold Go backend in `kubernetes/labs/chaos-citadel/backend/` (or dedicated standalone repo `chaos-citadel`).
   - Implement `outer-gate`, `market`, `treasury`, and `game-controller` with embedded mobile UI, RBAC definitions, concurrent cast cooldowns, and automatic match reset.
4. **Step 4: Manifests & Policies:**
   - Package Kubernetes manifests (Deployments, Services, RBAC, CiliumNetworkPolicy, node-safe CCNP, and EgressGatewayPolicy with mock external bank service).
5. **Step 5: Local Deployment & Playtesting on `kind-dev-01`:**
   - Deploy into `kind-dev-01`, label the designated egress gateway worker node, port-forward game controller and Hubble UI, and run end-to-end playtest.

---

## 8. Long-Term Evolution: The Zero-Trust & Chaos Campaign

As the infrastructure expands alongside the [Zero Trust & Chaos Lab](zero-trust-chaos-lab.md), Chaos Citadel will evolve from a pure networking demo into a modular, multi-level platform security and resilience arena:

```ascii
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CHAOS CITADEL: CAMPAIGN ROADMAP                       │
├─────────────────────────────────────────────────────────────────────────────┤
│ Level 1: eBPF Shields (Cilium & Hubble)                                     │
│   • L3/L4/L7 Curfew, Host Firewall (Node Hardening), Egress Gateway         │
├─────────────────────────────────────────────────────────────────────────────┤
│ Level 2: Environmental Cataclysms (Chaos Mesh)                              │
│   • "Earthquake" (PodChaos) ➔ Test HPA and endpoint churn resilience        │
│   • "Swamp Fog" (NetworkChaos) ➔ Latency/packet drops stalling trade flows  │
│   • "Curse of Confusion" (DNSChaos) ➔ Scrambles CoreDNS resolution          │
├─────────────────────────────────────────────────────────────────────────────┤
│ Level 3: The Royal Inquisitor (Cilium Tetragon / Falco / Datadog CSM)       │
│   • "Sleeper Agent" ➔ Container escape & unauthorized shell execution        │
│   • In-Kernel Enforcement ➔ Tetragon TracingPolicy kills process (SIGKILL)   │
│   • Automated Quarantine ➔ Falco/Datadog alert triggers eBPF isolation      │
├─────────────────────────────────────────────────────────────────────────────┤
│ Level 4: The Royal Cryptographic Seal (SPIFFE / SPIRE)                      │
│   • "The Imposter" ➔ Raiders spoof pod labels (app: market-square)          │
│   • Cryptographic mTLS ➔ SPIFFE ID verified at handshake; labels ignored    │
├─────────────────────────────────────────────────────────────────────────────┤
│ Level 5: The Mirage Caravan (Argo Rollouts + Shadow Traffic)                │
│   • Dark launch v2 service; 100% real traffic mirrored without user impact  │
│   • Chaos injected into shadow route with zero Citadel HP impact            │
└─────────────────────────────────────────────────────────────────────────────┘
```
