# Tower Defense: The eBPF Fortress

> **Status:** Architecture & Technical Specification  
> **Target Platform:** Kubernetes (`kind-dev-01`, extensible to cloud/GKE)  
> **Core Technologies:** Go (Golang), Cilium CNI, Hubble, eBPF, Kubernetes CRDs  

---

## 1. Executive Summary & Purpose

"Tower Defense: The eBPF Fortress" is an interactive, participatory multiplayer game designed to demonstrate the power of **Cilium eBPF networking, security, and Hubble observability** to a cross-functional audience:

- **Developers & DevOps:** Real-time visibility into L3/L4/L7 traffic, zero-code network troubleshooting, and automated topology discovery.
- **Platform & Security Engineers:** Instant Zero-Trust enforcement, kernel-level packet drops, eBPF Host Firewall node hardening, and deterministic Egress Gateway routing.
- **Data Engineers:** High-throughput data transfer visualization, wire encryption, and congestion monitoring.
- **Product Owners & Managers:** Direct visual link between platform security/reliability (Fortress HP) and business continuity/revenue (Treasury Gold).

Audience members participate from their smartphones or laptops, taking actions that generate real network packets and trigger dynamic Kubernetes resources, while Hubble UI serves as the real-time "Battlefield Radar" on the main display.

---

## 2. Repository Restructuring: Home Services vs. Labs

### The Challenge with Current Structure

Currently, the repository layout under `kubernetes/` directly conflates physical homelab production with the root:

```ascii
kubernetes/
├── applications/        # Home Assistant, Mosquitto, Zigbee2MQTT, ActualBudget
├── bootstrap/           # ArgoCD self-managed deployment
├── projects/            # ArgoCD AppProject definitions
└── system/              # Cloudflare Tunnel, Sealed Secrets
```

In `kubernetes/bootstrap/argo-cd/applications-applicationset.yaml`:

```yaml
directories:
  - path: kubernetes/applications/*
```

Because ArgoCD uses a git generator matching `kubernetes/applications/*`, any new folder added under `kubernetes/applications/` is **automatically discovered and deployed to the production Raspberry Pi cluster (`olympus.local`)**.

### Target Multi-Environment Architecture

To isolate production home services from experimental labs, benchmarks, and interactive games, we partition `kubernetes/` into distinct domains:

```ascii
kubernetes/
├── homelab/                     # Production smart-home workloads (olympus.local)
│   ├── bootstrap/               # ArgoCD root bootstrap for Olympus
│   ├── projects/                # ArgoCD AppProjects (applications, system)
│   ├── applications/            # User applications (actualbudget, homeassistant, etc.)
│   └── system/                  # Core infrastructure (cloudflare, sealed-secrets)
│
└── labs/                        # Experimental, training, and demo workloads (Kind, GKE)
    └── tower-defense/           # The eBPF Tower Defense Game
        ├── manifests/           # Core deployments, services, RBAC
        ├── policies/            # Pre-defined CiliumNetworkPolicy templates
        └── README.md            # Lab deployment & presenter guide
```

### Transition & ArgoCD Adjustments

1. **ApplicationSet Generator Update:**
   Update `kubernetes/homelab/bootstrap/argo-cd/applications-applicationset.yaml` to target `kubernetes/homelab/applications/*` and `kubernetes/homelab/system/*`.
2. **Cluster Targeting:**
   Workloads in `kubernetes/labs/` can be applied either directly via `kubectl` / Kustomize during local workshops, or via a dedicated `labs` ArgoCD ApplicationSet on dev clusters.
3. **No Cross-Contamination:**
   Changes to game rules or test applications will never trigger ArgoCD syncs on the production home server.

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
kubernetes/labs/tower-defense/
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
   - Holds the game loop (HP, Gold, match timer).
   - Uses `client-go` and Cilium's typed client to dynamically apply, toggle, and remove `CiliumNetworkPolicy` CRDs in the cluster when defenders cast spells.

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
  namespace: tower-defense
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
   - Cilium compiles the rule into eBPF socket and datapath programs.
   - Packets from `outer-gate` are **instantly rejected in the kernel** at the socket layer.
   - `outer-gate` receives `403 Forbidden` / connection reset.
   - **Hubble UI** displays glowing red dropped flows in real time with the verdict `DROPPED (Policy denied)`.

### Spell 2: Fortify the Foundations (Cilium Host Firewall)

Protects the underlying Kubernetes node physical/virtual network interfaces directly from sapper attacks attempting to probe SSH (22) or the Kubelet API (10250):

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
    - fromEntities:
        - cluster
      toPorts:
        - ports:
            - port: "6443"
              protocol: TCP
    # Reject raw sapper probes to port 22 or 10250 from untrusted sources
```

**Kernel Effect:** When active, eBPF programs attached to the host's NIC (`eth0`) drop non-whitelisted node packets before the Linux network stack even processes them.

### Spell 3: The Royal Treaty Route (Cilium Egress Gateway)

Routes high-value merchant deposits headed for the external **Allied Realm Bank** through a dedicated gateway node that SNATs the packets with a predictable, static egress IP:

```yaml
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: spell-royal-treaty-route
  namespace: tower-defense
spec:
  selectors:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: market-square
  destinationCIDRs:
    - "198.51.100.100/32"    # External Allied Realm Bank IP
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
   - Explain how eBPF accomplished this with zero Envoy sidecars and zero application code changes.
   - Show how the Terraform module automated the entire infrastructure.

---

## 7. Implementation Roadmap

1. **Step 1: Structural Reorganization:**
   - Partition `kubernetes/` into `kubernetes/homelab/` (production smart home) and `kubernetes/labs/` (sandbox, experiments, games).
   - Update `applications-applicationset.yaml` and verify ArgoCD paths.
2. **Step 2: Go Microservices & Controller:**
   - Scaffold Go project in `kubernetes/labs/tower-defense/backend/`.
   - Implement `outer-gate`, `market`, `treasury`, and `game-controller` with embedded mobile UI.
3. **Step 3: Manifests & Policies:**
   - Package Kubernetes manifests (Deployments, Services, RBAC, NetworkPolicies).
4. **Step 4: Local Deployment on `kind-dev-01`:**
   - Deploy into `kind-dev-01`, port-forward game controller and Hubble UI, and run end-to-end playtest.
