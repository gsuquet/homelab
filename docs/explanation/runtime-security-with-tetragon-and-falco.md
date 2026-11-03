# Runtime security with Tetragon and Falco

The Conftest policies and the Pod Security levels stop a bad manifest before it runs. They do not see what a process does after its start. Examples are a shell in a container, a read of `/etc/shadow`, or a binary that a process writes and then runs. Runtime security tools watch the kernel for these events, and some can stop the process.

The platform has two such tools, Tetragon and Falco. Both use eBPF, and both cover the same attack steps. They differ in how they detect, in what they can stop, in their cost and in their operation. This page tells why the platform keeps both, how the comparison between them works, and what `kind-local` cannot show.

## Why two tools, and why both stay

Tetragon and Falco answer the same need from two directions.

- **Tetragon** attaches eBPF programs to kernel functions, for example `security_file_permission` or `tcp_connect`. A `TracingPolicy` names the hook and the selectors. A policy can also act: `Sigkill` stops the process, and `Override` makes the kernel function return an error. Tetragon is a Cilium project, and its events have the Kubernetes pod of each process.
- **Falco** reads the system calls through its modern eBPF driver and matches them against rules. Its stable rule set has rules for many attack steps, with no authoring. Falco only detects. Falco Talon is a separate program, and `program_output` sends each alert to a program.

The two tools thus have different strengths: Tetragon can enforce, and Falco has rules ready for use. A comparison on the same attack set gives facts for each of the four areas: detection, enforcement, overhead and operations. One tool is the default to run, and the comparison report chooses it from these facts.

Both components stay in the repository after the comparison. They are the material for demonstrations, explanations and presentations to other people. A comparison that a person can run again on a laptop has more value than a static report. The cost is two components to keep current.

## The install switch

Each tool is one independent component, `tetragon` or `falco`, with its own Namespace. `cluster.yaml` enables each component on its own, with no `dependsOn` between them. This gives three useful modes:

- One tool only. The overhead numbers of the tool are clean, because no other agent shares the kernel.
- The two tools. One run of the attack set gives the events of both tools side by side, with one run ID.
- No tool. The base for the overhead numbers.

The two components are `infrastructure` components, because they install CRDs and `ClusterRole` objects. The `apps` AppProject refuses these kinds. Each component ships its own Namespace, and not `kube-system`, the namespace of the upstream guides. A component cannot ship a Namespace that exists before it, and K15 permits only the namespace of the component.

Tetragon is a separate chart, not a value of the Cilium chart. The Cilium chart has no Tetragon value. Thus Tetragon is a GitOps component, and the `bootstrap-cilium` module does not change. The two projects share no CRD names, and they pin their BPF maps in different folders.

Both tools install the same way: one Helm chart each, rendered and synced by Argo CD. This keeps the operations part of the comparison fair.

## How the comparison works

The `security:attack-set` task runs one scripted attack set against the two tools. The steps come from [falcosecurity/event-generator](https://github.com/falcosecurity/event-generator), the test tool of the Falco project, pinned by its digest. An upstream test tool gives steps that other people use and review, and the repository keeps no attack code of its own. A step that `event-generator` does not cover is not in the set, or it is a plain shell command.

Each step is harmless and stays in the namespace `rtsec-lab`. The task creates this namespace, applies the lab fixtures, runs the steps, and deletes the namespace at the end. No step needs a capability above the runtime default, touches a host path or connects to the internet. The set has no steps that touch the kernel or the host, for example a module load. These steps need privileges that a harmless lab must not have.

The task collects the logs one time, at the end of the run. Tetragon can emit an exec event up to about 30 seconds after the step, because its event cache retries the pod lookup. A short window after each step misses these events.

The `security:measure` task samples the memory and the CPU of the agents, the kind nodes and the Colima VM, in idle and under a fixed load. A clean number comes from one tool at a time, from a new cluster, against a run with no tool. The event volume comes from the metrics of each tool, not from the logs. Under load, the kubelet rotates the log files, and `kubectl logs` returns only the current file.

The alerts go to the standard output as JSON lines. `kubectl logs` and `jq` read them. An alert backend, for example Falcosidekick with Grafana, adds components that the comparison does not need.

## Why the Tetragon lab policies are test fixtures

The `tetragon` component holds only the tool. The Tetragon policies of the lab are test fixtures in `tests/runtime-security/`, and the attack-set task applies them. There are two reasons.

First, the lab policies are objects in the namespace `rtsec-lab`, and the task deletes this namespace after each run. Argo CD cannot keep an object `Synced` in a namespace that does not exist. Its self-heal then fails until the next run.

Second, an enforcement policy that is always on changes the detection results. An enforcement policy that is always on acts on the detection steps that use the same files or ports. For example, A8 runs in `enforce-target`, and an E2 block on port 4444 stops it. Thus the task applies the detection policies for the full run, and the enforcement policies only for the E steps.

The Falco lab rules are different. They stay in `customRules` of the `falco` component, and each rule has a condition on the namespace `rtsec-lab`. Falco reads its rules from files. A change of the rules at run time patches a ConfigMap that Argo CD manages, and Falco must restart. A Falco rule also never blocks a process, so a lab rule that is always on does not change the results.

## Why Falco has its settings

Falco uses the modern eBPF driver. The legacy eBPF probe does not exist in Falco 0.44.0 and later ([release 0.44.0](https://github.com/falcosecurity/falco/releases/tag/0.44.0)). The kernel module needs a driver for each kernel, a privileged loader and host folders. Talos forces a signature check on all modules, so an unsigned Falco module cannot load on the Pi nodes. The modern driver needs BTF and a kernel 5.8 or later ([kernel event sources](https://falco.org/docs/concepts/event-sources/kernel/)).

Falco runs with capabilities, not as a privileged container. The `leastPrivileged` set of the chart alone does not start on Colima. The Colima VM has `kernel.perf_event_paranoid = 4`, and at this level `CAP_PERFMON` cannot open the tracepoints. With `SYS_ADMIN` added to the set, Falco starts with no dropped events.

The rules and the container plugin come from the Falco image, pinned by its digest. The image has the stable rule set of `falco-rules` 5.2.0 and the plugin `container` 0.7.6. Thus Falco fetches no artifact at its start, and a rule change always comes from a Git change. With `falcoctl`, the rules come from `ghcr.io` at each start, and the follow mode changes the rules with no Git change.

## Why enforcement stays in the lab namespace

The two kind nodes of `kind-local` are containers on one kernel, the kernel of the Colima VM. An eBPF program that one agent loads sees the system calls of the full VM. These include the two kind nodes, the Docker daemon and all the other containers of the laptop.

Thus a cluster-scoped `TracingPolicy` with `Sigkill` loads on the two agents and acts on each process of the VM, also on the kind nodes. Each enforcement policy is a `TracingPolicyNamespaced` in `rtsec-lab`, with a `podSelector` on the label `rtsec.gsuquet.com/role: enforce`. Only the pod `enforce-target` has this label, so the enforcement steps do not stop the detection steps in the other lab pods. The K17 check refuses a cluster-scoped `TracingPolicy` with an enforcement action or an enforcer. The full list is in [Checks](../reference/runtime-security-components.md#checks). The same rule also protects a real node, where an error in a cluster-scoped kill policy can stop a system process.

The two agents are host-level DaemonSets. They read each process, file event and network event of the node, and Tetragon can stop processes. A compromise of an agent is a compromise of its node. K16 permits a privileged container only in the namespaces `tetragon` and `falco`. In these components, the Tetragon init container `mount-bpf-fs` is the only privileged container. The allowlist in the policy data keeps this privilege visible.

## What `kind-local` does not show

`kind-local` is the first place for the comparison, but its shared kernel changes some results.

- **Duplicate events.** Each lab event reaches the two agents. Tetragon emits the copy of the other node with no pod, and its deny list drops it from the output. Falco prints each alert two times. The copy of the other node has no Kubernetes fields, and a filter on the namespace removes it.
- **Host noise.** Falco also alerts on processes of the containers outside Kubernetes in the VM. The comparison counts only the events of `rtsec-lab`. Host-level detections on a kind node are not the same as on a real node, so they wait for the Pi nodes.
- **PID namespaces.** A kind node has its own PID namespace, but the BPF events carry the PIDs of the VM. With the `/proc` of the node, Tetragon loses the parent of the processes older than the agent. `cluster-kind` thus mounts the `/proc` of the VM at `/procHost` in each node, and Tetragon reads it. The mount is read-only, but it is not an isolation boundary: `/procHost/<pid>/root` reaches the file system of the VM. A Conftest check permits this host path only in the namespace `tetragon`. A real node needs no such mount.
- **Cilium socket load balancing.** Cilium changes a ClusterIP to a backend address at the connect. `tcp_connect` sees the backend, and `security_socket_connect` sees the ClusterIP. Thus a detection of the API server uses the node IPs on port 6443. The stable Falco rule on the service name does not match.
- **Overhead.** Two agents on one VM double the kernel cost, when compared with one agent on each real node. The numbers on `kind-local` compare the two tools on the same base. They are not absolute numbers.
- **Other kind clusters.** The VM has `fs.inotify.max_user_instances = 128`. A third kind node in the same VM, for example a throwaway test cluster, cannot start `kube-proxy`.

The Pi nodes run Talos with its own kernel. The repository has no measurement on these nodes. The presence of BTF and `CONFIG_BPF_KPROBE_OVERRIDE`, the lockdown state and the value of `perf_event_paranoid` on the Talos kernel of the Pi 4 have no check.

## Alternatives

Other designs can also give runtime security. Each one is a worse match for the comparison.

- **One component with the two tools** cannot run one tool alone. The overhead numbers then mix the two tools.
- **One tool only, and the deletion of the other after the comparison** removes the material for demonstrations and for a new run of the comparison.
- **Lab policies in the `tetragon` component** keep the policies in Git with the tool. But Argo CD cannot keep them `Synced` when the task deletes `rtsec-lab`, and the enforcement policies are then always on.
- **Attack code in the repository** gives full control of each step. But the repository then keeps and reviews attack code. A pinned upstream test tool gives the same steps to each person who runs it.
- **`hostProcPath: /proc` on kind** needs no cluster change, and pods that start after the agent keep their attribution. But processes older than the agent lose their parent, and `kubectl exec` shells show a wrong parent.
- **A one-node `kind-local`** removes the duplicate events. But it does not show the behavior of two agents and two nodes, which the Pi cluster also has.
- **Tetragon in the `kube-system` namespace**, as in the upstream guides, breaks the namespace rule of the components. Tetragon also filters the `kube-system` events by default.
- **Tetragon CRDs from the operator** (the chart default) makes CRDs that Argo CD does not track, and the operator needs the right to create CRDs.
- **Falco as a privileged container** (the chart default) gives more privileges than necessary. The capability set with `SYS_ADMIN` is enough.
- **The Falco Operator** is the install method that falco.org recommends ([setup](https://falco.org/docs/setup/kubernetes/)). With it, the two tools do not install the same way, and the operations comparison is less fair.
- **Other tools**, for example KubeArmor or Tracee, are outside the subject.

## Related pages

- [Runtime security components](../reference/runtime-security-components.md)
- [Run the runtime security attack set](../how-to/run-the-runtime-security-attack-set.md)
- [Remove a runtime security tool](../how-to/remove-a-runtime-security-tool.md)
- [Why the platform runs on a local cluster first](why-the-platform-runs-on-a-local-cluster-first.md)
- [GitOps with Argo CD](gitops-with-argo-cd.md)
