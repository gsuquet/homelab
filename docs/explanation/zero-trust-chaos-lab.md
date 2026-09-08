# Zero Trust, Shadow Traffic & Chaos Engineering Lab

> Status: scoping draft — ongoing R&D, no fixed deadline.

## Context and goals

This is a **testing lab**, not a single fixed stack: reusable Terraform
modules that let different products be installed, benchmarked head-to-head,
and demonstrated for a given client or setup, across four related
Kubernetes topics:

1. **Zero Trust networking** — strong per-workload identity, default-deny,
   systematic encryption of east-west traffic.
2. **Security** — admission control, runtime detection, supply chain.
3. **Shadow traffic** — mirroring production traffic to a candidate version
   with no user impact, to validate before cutover.
4. **Chaos engineering** — controlled fault injection to verify that
   resilience and security guarantees hold under stress.

It relies primarily on **CNCF** projects (graduated or incubating), with one
deliberate exception: Datadog is a permanent, first-class module for
observability and security, used whenever a given setup or client calls for
it — see [Selectable modules per pillar](#selectable-modules-per-pillar).

Dual purpose:

- **Client offering**: benchmark results back a recommendation instead of a
  single fixed opinion — "here's Datadog vs. Falco/Prometheus on this
  cluster, here are the numbers" is more useful in pre-sales than a single
  pre-picked stack.
- **External conference**: a condensed, more accessible format built from
  the same demo scenarios.

## Scope

**In scope:**

- Reusable Terraform modules, tested locally (kind) then on a managed cloud
  cluster (GKE first).
- Configurable modules per pillar, so a given demo/client setup can select
  which product to run — e.g. pure Cilium vs. Cilium + Istio ambient,
  Datadog vs. Falco + Prometheus/Grafana — rather than a single final stack.
- Concrete demo scenarios (not just component installation).
- Benchmark/comparison notes per pillar (perf, complexity, cost) to support
  recommendations.
- Diataxis documentation in this repo (`docs/reference/terraform-modules/`)
  and a presentation deck.

**Out of scope (for now):**

- Simultaneous multi-cluster / multi-cloud provisioning.
- Integration with an external enterprise IdP (human SSO) — zero trust here
  targets **workload-to-workload** identity, not user authentication.
- Formal certification / compliance (PCI-DSS, ISO 27001...).

Given the "ongoing R&D" time budget, the project is built up in phases (see
below), and each phase may compare several alternatives — CNCF or not —
before those alternatives become permanent, selectable options in the lab.

## Selectable modules per pillar

| Pillar | Baseline | Configurable alternative | Notes |
| --- | --- | --- | --- |
| CNI / network zero trust | **Cilium** (pure — CNI, L3-L7 network policies, transparent encryption via WireGuard/IPsec, Hubble) | + **Istio (ambient mode)** as an optional add-on layer | Iteration 1 uses pure Cilium, no mesh. Istio ambient is added later, specifically where pure Cilium falls short — L7 traffic mirroring for shadow traffic — not as a default part of the stack. |
| Workload identity | **SPIFFE / SPIRE** | — | Relevant regardless of the mesh choice above. |
| Shadow traffic | **Argo Rollouts** (`setMirrorRoute`) driving **Istio** traffic routing | Gateway API traffic-routing plugin (would let Cilium's own Gateway API drive mirroring, no Istio needed) | Argo Rollouts (CNCF graduated, part of the Argo family) is the orchestration layer. As of today, only its built-in Istio provider implements mirroring; [PR #4643](https://github.com/argoproj/argo-rollouts/pull/4643) (merged into `master`, May 2026) generalized the mirroring validation so *any* traffic-routing plugin can implement it. The Gateway API plugin's own mirroring support is the natural next step on the public roadmap — re-check its status before phase 2; if it lands and Cilium's Gateway API mirror filter is confirmed usable with it, the Istio add-on may become unnecessary for this pillar. |
| Policy as code / admission | **Kyverno** | OPA/Gatekeeper (Rego, more verbose) | |
| Runtime security | **Datadog** (Cloud Security Management) | **Falco** (syscall/kernel-level anomaly detection, CNCF graduated) | Both are kept as permanent, selectable options — Datadog for managed/SaaS-oriented setups, Falco for fully self-hosted/OSS requirements. |
| Cross-cutting observability | **Datadog** (dashboards, APM, network monitoring) | **Prometheus + Grafana** (+ Hubble UI) | Same logic: both stay in the lab, chosen per setup rather than one replacing the other. |
| Chaos engineering | **Chaos Mesh** | LitmusChaos (more workflow/GitOps-oriented) | |
| Supply chain (stretch) | **Trivy** (+ optional cosign/Sigstore) | — | |

The build-out order still starts simple (pure Cilium, Datadog available but
optional) and adds layers incrementally — see the [roadmap](#phased-roadmap)
— but the end state is a lab where these are all standing, selectable
options, not a single stack that later choices replace.

### Why pure Cilium first

Cilium alone (no service mesh) already covers L3-L7 network policies,
workload-based identity for policies, and transparent encryption. Adding
Istio on day one would mean paying its operational complexity before
proving it's needed. Istio ambient is introduced later, purely to unlock
the one thing pure Cilium doesn't do: L7-level traffic mirroring for the
shadow-traffic scenarios. Once built, both configurations (Cilium-only,
Cilium+Istio) remain available in the lab as a documented comparison
("here's the complexity/feature trade-off of adding a mesh").

Argo Rollouts sits on top of that mesh decision, and its scope there is
actively changing. As of today, its shipped mirroring feature
(`setMirrorRoute`) only works through the built-in Istio provider. But
[PR #4643](https://github.com/argoproj/argo-rollouts/pull/4643) (merged
May 2026) removed the validation that hard-coded this to Istio, opening the
door for the Gateway API traffic-routing plugin to implement mirroring too
— which is the plugin's stated next step, and Cilium's own Gateway API
implementation appears to already support an HTTP mirror filter (confirm
against current Cilium docs before relying on it). If that combination lands
and is verified working, pure Cilium + Argo Rollouts could cover
shadow traffic without an Istio add-on at all.

Until that's confirmed and tested, treat Istio as the working baseline for
phase 2 and re-evaluate at build time — this is exactly the kind of
fast-moving CNCF ecosystem detail flagged in
[Risks and caveats](#risks-and-caveats).

### Why Datadog stays

Datadog is not a CNCF project, but the lab's purpose is to compare products,
not to enforce OSS purity. It's built as a single `datadog` Terraform module
with feature flags (APM, CSM, network monitoring, ...) so a given setup
enables only what it needs. Falco + Prometheus/Grafana + Hubble UI are built
alongside it as the fully self-hosted alternative. Neither retires the
other — the value of the lab is being able to spin up either (or both, for
a side-by-side demo) depending on what a client's environment or interest
calls for.

## Terraform environments

The repo already has a `terraform/modules/kind-cluster/` module (local
cluster) — reused as the foundation. Planned structure:

```ascii
terraform/
  modules/
    kind-cluster/      # existing
    cluster-gke/        # new, first managed-cloud provider
    cilium/             # CNI + network policies (install only), configurable
                         # for multiple scenarios (standalone or paired with
                         # istio-ambient)
    hubble/              # Cilium's observability layer (UI, relay)
    spire/               # workload identity
    istio-ambient/       # optional add-on: L7 mesh, mTLS, mirroring
    argo-rollouts/       # progressive-delivery controller, drives shadow traffic
    kyverno/
    datadog/             # configurable observability + security, permanent
    falco/               # configurable runtime security, permanent
    chaos-mesh/
    observability-stack/ # kube-prometheus-stack, permanent
  templates/
    zero-trust-lab-local/  # kind + selected modules, composed per scenario
    zero-trust-lab-cloud/  # same composition on a managed cluster
```

Each module follows the repo's existing conventions (terraform-docs,
`mise run doc:generate`, matching doc entry under
`docs/reference/terraform-modules/<module>/index.md`).

No shared multi-provider abstraction: each managed cloud gets its own
top-level module (`cluster-gke`, and later `cluster-ask` / `cluster-eks` if
needed) rather than provider sub-modules under a common `cloud-cluster`
parent. **GKE is the first provider** to implement.

Cilium's CNI installation and its observability layer (Hubble) are split
into two modules (`cilium` and `hubble`) so either can be enabled
independently. The `cilium` module itself is configurable to support
multiple scenarios (e.g. standalone vs. paired with `istio-ambient`), rather
than assuming one fixed topology.

`datadog`, `falco`, and `observability-stack` are all permanent, standing
modules — a given `templates/*` composition picks which ones it wires up.

## Phased roadmap

| Phase | Content | Output |
| --- | --- | --- |
| 0 — Foundations | kind cluster + pure Cilium (CNI) + Hubble; Datadog available as an opt-in module | `cilium`, `hubble`, `datadog` modules, working dashboards |
| 1 — Identity & network zero trust | SPIRE + `CiliumNetworkPolicy` in default-deny mode, still no mesh | `spire` module + versioned network policies, default-deny demo |
| 2 — Shadow traffic add-on | Argo Rollouts driving mirroring through Istio ambient (working baseline); spike whether the Gateway API plugin + Cilium's mirror filter can replace Istio once available | `argo-rollouts`, `istio-ambient` modules, no-impact A/B demo scenario, spike notes |
| 3 — Policy & runtime security | Kyverno (admission) + runtime security, built for both Datadog CSM and Falco | `kyverno`, `datadog`, `falco` modules, side-by-side security signals |
| 4 — Chaos engineering | Chaos Mesh: pod kill, network latency, partition — combined with zero trust policies | `chaos-mesh` module, quick comparison with LitmusChaos |
| 5 — Cloud validation | Replay scenarios 0-4 on a managed cluster | `cluster-gke` module, porting notes (cloud CNI differences, cost) |
| 6 — Final deliverables | Benchmarks, comparisons, documentation consolidation, slides | Presentation deck, documented and publishable Terraform modules |

Phases are intentionally iterative: each one can be presented on its own if
an opportunity (client, conference) comes up before the project wraps up.

## Demo scenarios

These are the scenarios that will structure the presentation deck — the
platform alone isn't a compelling deliverable for a client.

1. **Proven default-deny**: two services deployed without an explicit policy
   cannot communicate; add a `CiliumNetworkPolicy` + SPIFFE identity to
   authorize one specific flow, visible in Hubble. Pure Cilium, no mesh.
2. **Risk-free shadow traffic**: a new service version receives a copy of
   real traffic via Argo Rollouts' `setMirrorRoute` (through Istio today,
   potentially through Cilium's own Gateway API mirror filter once the
   Gateway API traffic-routing plugin supports it) without ever responding
   to the client — real-condition validation before cutover.
3. **Chaos during shadow traffic**: inject latency/network failure on the
   candidate version while mirroring is active, to verify observability
   catches the problem before it ever reaches production.
4. **Simulated intrusion**: a compromised pod attempts lateral movement;
   Cilium blocks the unauthorized network flow, and a runtime alert fires —
   run once with Datadog CSM, once with Falco, to compare detection and
   signal quality side by side.

## Expected deliverables

- Terraform modules (list above), documented and tested both locally and on
  a managed cloud cluster.
- Diataxis documentation: one reference entry per module + a how-to for
  "running a demo scenario" and "selecting a module configuration for a
  given setup".
- Presentation deck, reusable in two formats: long version (client pre-sales)
  and condensed version (conference).
- A benchmark/comparison report per pillar (Cilium-only vs. Cilium+Istio,
  Datadog vs. Falco+Prometheus/Grafana, Chaos Mesh vs. Litmus) covering
  performance, operational complexity, and cost — the core value of the lab
  for client conversations.

## Risks and caveats

- **Combined stack complexity** (Cilium + Istio): clearly document the
  split of responsibilities so the audience doesn't get lost during a demo.
- **Cloud cost**: phase 5 involves a billed managed cluster (GKE) — always
  run `terraform destroy` after each test session.
- **CNCF version drift**: these projects move fast (e.g. Istio ambient mode
  is still stabilizing, and Argo Rollouts' Gateway API mirroring support was
  still unshipped as of this writing); check the state of the art before
  each phase rather than trusting this document.
- **Datadog cost**: it's a paid SaaS with usage-based billing — scope
  enabled features tightly via the module's flags, and only turn it on for
  the setups/demos that actually need it.
- **Maintenance surface**: keeping multiple implementations per pillar
  (Cilium-only vs. +Istio, Datadog vs. Falco/Prometheus) working and
  up to date is more effort than committing to one — budget for it
  explicitly rather than letting one side silently rot.

## Open questions

- Has the Argo Rollouts Gateway API plugin shipped mirroring support by the
  time phase 2 starts, and is Cilium's Gateway API mirror filter confirmed
  compatible with it? If yes, is it worth dropping Istio from phase 2
  entirely rather than keeping it as an add-on?
- Does the "simulated intrusion" scenario need a dedicated attack-simulation
  tool (e.g. reproducing a known CVE), or is a simple manual command inside a
  pod enough for the demo?
- Should the supply chain track (Trivy/Sigstore) be included in the first
  iteration, or kept as a later stretch goal?
- Which pillars warrant a genuine quantitative benchmark (latency, resource
  overhead) vs. a qualitative comparison only (setup complexity, DX)?
