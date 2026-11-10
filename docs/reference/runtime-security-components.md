# Runtime security components

The `tetragon` and `falco` components install the two runtime security tools of the platform with Argo CD. Each component is an `infrastructure` component in `gitops/infrastructure/`, with its own Namespace. A cluster enables each component on its own, in `cluster.yaml`. The reasons are in [Runtime security with Tetragon and Falco](../explanation/runtime-security-with-tetragon-and-falco.md).

| Item | File | Description |
| --- | --- | --- |
| `tetragon` | `gitops/infrastructure/tetragon/sources/` | Umbrella chart for Tetragon. No lab policies. |
| `falco` | `gitops/infrastructure/falco/sources/` | Umbrella chart for Falco, with the Falco lab rules in `customRules` |
| Kind values | `gitops/clusters/kind-local/values/tetragon.yaml` | The values of Tetragon for `kind-local` only |
| Attack set | `.mise/tasks/security/attack-set.sh` | The task that runs the attack steps |
| Lab fixtures | `tests/runtime-security/` | The lab pods and the Tetragon lab policies. Refer to [Lab fixtures](#lab-fixtures). |
| Measurement | `.mise/tasks/security/measure.sh` | The task that samples the memory, the CPU and the event volume |

The syntax of the `security:*` tasks is in [Mise tasks](mise-tasks.md).

## Switch

Each tool is one item of the `infrastructure` list in `gitops/clusters/<cluster>/cluster.yaml`. A cluster can enable one tool, the two tools, or none.

```yaml
infrastructure:
  - name: argocd
    namespace: argocd
  - name: tetragon
    namespace: tetragon
  - name: falco
    namespace: falco
```

| Item | `name` | `namespace` | `dependsOn` |
| --- | --- | --- | --- |
| Tetragon | `tetragon` | `tetragon` | None |
| Falco | `falco` | `falco` | None |

## Versions and images

| Item | Version | Source |
| --- | --- | --- |
| Tetragon chart | `tetragon` 1.8.0, `appVersion` 1.8.0 | `https://helm.cilium.io` ([install](https://tetragon.io/docs/installation/kubernetes/)) |
| Falco chart | `falco` 9.2.2, `appVersion` 0.45.2 | `https://falcosecurity.github.io/charts` ([setup](https://falco.org/docs/setup/kubernetes/)) |
| Falco | 0.45.2, libs 0.26.1, driver 11.0.1 | [Release 0.45.2](https://github.com/falcosecurity/falco/releases/tag/0.45.2) |
| Falco rules | `falco_rules.yaml` of the Falco image, equal to [falco-rules 5.2.0](https://github.com/falcosecurity/rules/blob/falco-rules-5.2.0/rules/falco_rules.yaml) (stable rule set, 25 rules) | The Falco image |
| Falco container plugin | `container` 0.7.6, `/usr/share/falco/plugins/libcontainer.so` | The Falco image |
| event-generator | `docker.io/falcosecurity/event-generator` v0.13.0, pinned by tag and digest | [falcosecurity/event-generator](https://github.com/falcosecurity/event-generator) |

`Chart.yaml` of each component has the exact chart version. The values set each image with its tag and its digest. Each image is an OCI image index for `linux/amd64` and `linux/arm64`.

```text
quay.io/cilium/tetragon:v1.8.0@sha256:5ed9088a1582131d71b06c98e0d549a37a71ae63ab13aabefc7a47553c822a9d
quay.io/cilium/tetragon-operator:v1.8.0@sha256:af2b6f0a8609d66190f1d5bbdea38a160d5460f2ea416beea42a615aadd8b35a
quay.io/cilium/hubble-export-stdout:v1.1.1@sha256:cf701f96d1c8de30231792e35733e1ab07451e11751ef4f676f482836759da06
docker.io/falcosecurity/falco:0.45.2@sha256:1562a643953f938e02f47319b5214d93a235f11f646d60e9b8a516fd5a64698e
```

The attack-set task uses this image:

```text
docker.io/falcosecurity/event-generator:0.13.0@sha256:932956d86c99a96a9d6cf71970ae23de94ebc119a0ff19b1acf75b8db43ac165
```

The digest of the Falco image pins the Falco rules and the container plugin. The `falco_rules.yaml` file of this image has the sha256 `30a1a60263ab97650c851011468da03b17fc0096a7cfa3b6686eba5de73b865b`.

## Namespaces

`sources/templates/namespace.yaml` of each component ships its Namespace.

| Label or annotation | Value |
| --- | --- |
| `pod-security.kubernetes.io/enforce`, `audit`, `warn` | `privileged` |
| `tenant.infra.gsuquet.com/name` | `platform` |
| `ownership.infra.gsuquet.com/owner` | `gsuquet` |
| `app.kubernetes.io/*` | The labels of [Labels and annotations](labels-and-annotations.md) |
| `argocd.argoproj.io/sync-wave` | `"-2"` |

## Tetragon values

The names are the values of the upstream chart. In the umbrella chart, they are below the key `tetragon`.

| Value | Setting |
| --- | --- |
| `crds.installMethod` | `helm`. The three CRDs are templates of the release, with the sync wave `-1`. |
| `tetragonOperator.enabled` | `true`. The operator manages the `PodInfo` objects. |
| `export.mode` | `stdout`. The `export-stdout` container prints one JSON event on each line. |
| `tetragon.enableProcessCred` | `true`. Adds the process credentials to the events. |
| `tetragon.exportDenyList` | The chart entries `{"health_check":true}` and the namespaces `""`, `kube-system` and `cilium`, plus the namespaces `tetragon` and `falco` |
| `tetragon.prometheus.enabled` | `true`. Port 2112. |
| `tetragon.grpc.enabled` | `true`, on a Unix socket of the host only |
| `tetragon.hostProcPath` | `/procHost` on `kind-local`, in `gitops/clusters/kind-local/values/tetragon.yaml`. `/proc` on the other clusters. |
| Resources | Refer to [Footprint](#footprint). The chart default is `{}`. |

The component owns the CRDs `tracingpolicies.cilium.io`, `tracingpoliciesnamespaced.cilium.io` and `podinfo.cilium.io`. The `cilium*` CRDs stay with Terraform, in the `bootstrap-cilium` module. `helm uninstall` of the release deletes the three CRDs, and with them all the `TracingPolicy` and `TracingPolicyNamespaced` objects.

## Falco values

The names are the values of the upstream chart. In the umbrella chart, they are below the key `falco`.

| Value | Setting |
| --- | --- |
| `driver.kind` | `modern_ebpf`. No driver loader init container. |
| `containerSecurityContext` | `privileged: false`. Capabilities `BPF`, `SYS_RESOURCE`, `PERFMON`, `SYS_PTRACE` and `SYS_ADMIN`. |
| `falco.json_output` | `true` |
| `falco.stdout_output.enabled` | `true` |
| `falco.syslog_output.enabled`, `falco.log_syslog` | `false` |
| `falco.http_output.enabled` | `false` |
| `falcosidekick.enabled` | `false` |
| `responseActions.enabled` | `false` |
| `collectors.kubernetes.enabled` | `false`. No k8s-metacollector. The container plugin reads the CRI socket. |
| `collectors.containerEngine.engines` | `containerd` and `cri` on. `docker`, `podman`, `lxc`, `libvirt_lxc` and `bpm` off. |
| `falcoctl.artifact.install.enabled`, `falcoctl.artifact.follow.enabled` | `false`. No `falcoctl` container. The rules and the plugin come from the image. |
| `customRules` | The Falco lab rules. Refer to [Falco lab rules](#falco-lab-rules). |
| `metrics.enabled`, `falco.webserver.prometheus_metrics_enabled` | `true`. Port 8765. |
| Resources | Refer to [Footprint](#footprint). |

## Falco lab rules

`customRules` of the `falco` component adds these rules to the stable rule set of the image. Each rule has the condition `k8s.ns.name = "rtsec-lab"`, so it fires only for the lab. The rules are always on.

| Rule | Condition |
| --- | --- |
| `Write below etc` | A process in a container of `rtsec-lab` opens a file below `/etc` for a write. From the [Falco quickstart](https://falco.org/docs/getting-started/falco-kubernetes-quickstart/). |
| API server endpoint | A connection from a container of `rtsec-lab` to any IP on port 6443 (`fd.sport=6443`). With Cilium socket load balancing, this IP is the node IP. |

## Lab fixtures

The `tetragon` component holds only the tool. It has no `TracingPolicy` and no `TracingPolicyNamespaced`. The lab pods and the Tetragon lab policies are test fixtures in `tests/runtime-security/`. Argo CD does not sync them.

| Fixture | Content | Applied | Deleted |
| --- | --- | --- | --- |
| Lab pods | The pods of the attack steps, and the pod `enforce-target` with the label `rtsec.gsuquet.com/role: enforce` | At the start of the run | With `rtsec-lab` |
| Tetragon detection policies | `TracingPolicyNamespaced` objects in `rtsec-lab`, with the action `Post` only | For the full run | With `rtsec-lab` |
| Tetragon enforcement policies | `TracingPolicyNamespaced` objects in `rtsec-lab`, with a `podSelector` on `rtsec.gsuquet.com/role: enforce` | For the E steps only | After the E steps, and with `rtsec-lab` |

The Tetragon detection policies follow the paths and the arguments of the `event-generator` actions:

| Step | Hook or event | Selector |
| --- | --- | --- |
| A1, A4, A5, A6, A9 | `process_exec`, no policy | The binary path or the arguments, in the `jq` filter |
| A2 | `security_file_open` | Path prefix `/etc/shadow` |
| A3 | `security_path_mknod` | Dentry prefix `/etc` |
| A7 | `tcp_connect` | The API server endpoint: the node IPs, port 6443 |
| A8 | `tcp_connect` | The `listener` pod, port 4444 |
| A10 | `security_file_truncate` | The log file of the action |
| A11 | `create_user_ns` | None |
| A12 | `sys_ptrace` (`__arm64_sys_ptrace` on arm64) | None |

The hooks have no test with the `event-generator` actions.

The sources of the policies are the Tetragon [policy library](https://tetragon.io/docs/policy-library/observability/) and the [examples of v1.8.0](https://github.com/cilium/tetragon/tree/v1.8.0/examples).

The enforcement policies act only on the pod `enforce-target`:

| ID | Trigger in `enforce-target` | Hook | Selector | Action | Result |
| --- | --- | --- | --- | --- | --- |
| E1 | A plain read of `/etc/shadow` (shell) | `security_file_permission` | Path prefix `/etc/shadow`, `MAY_READ` | `Sigkill` | Exit status 137, action `KPROBE_ACTION_SIGKILL` |
| E2 | A connection to the `listener` pod on port 4444 (shell) | `security_socket_connect` | The listener port 4444 | `Override`, `argError: -1` | `Operation not permitted`. The process continues. |
| E3 | The create of a file below `/etc` (shell) | `security_path_mknod` | Dentry prefix `/etc` | `Override`, `argError: -1` | `Operation not permitted`. No file. |

Falco has no enforcement. For the E steps, the summary records "detect only" for Falco.

## Attack set

The attack steps come from [falcosecurity/event-generator](https://github.com/falcosecurity/event-generator), the test tool of the Falco project, or they are plain shell commands. The task pins the image by its tag and its digest. The repository has no attack code of its own. The task runs each action of the `syscall` collection with `--all` and an anchored regular expression that names exactly one action, for example `'^syscall\.WriteBelowEtc$'`. `--all` is necessary for A3 and A11, because `event-generator` disables them by default. The task never uses `--all` with a different expression, and it never runs an action that leaves the pod.

| ID | Behavior | Source |
| --- | --- | --- |
| A1 | Shell with a TTY in the lab pod | Shell |
| A2 | Read of a sensitive file | `ReadSensitiveFileUntrusted` |
| A3 | Write below `/etc` | `WriteBelowEtc` |
| A4 | Drop of a new binary in `/bin`, then its execution | `DropAndExecuteNewBinaryInContainer` |
| A5 | Execution from `/dev/shm` | `ExecutionFromDevShm` |
| A6 | Fileless execution through `memfd_create` | `FilelessExecutionViaMemfdCreate` |
| A7 | Connection to the API server | Shell |
| A8 | Connection to the lab `listener` pod, from `enforce-target` | Shell |
| A9 | Search for private keys or passwords | `SearchPrivateKeysOrPasswords` |
| A10 | Clear of a log file in a temporary folder | `ClearLogActivities` |
| A11 | Change of namespace privileges through `unshare` | `ChangeNamespacePrivilegesViaUnshare` |
| A12 | Ptrace attach to a process | `PtraceAttachedToProcess` |

The enforcement steps E1 to E3 run in the pod `enforce-target`. A8 also runs in `enforce-target`. Refer to [Lab fixtures](#lab-fixtures).

The `security:attack-set` task obeys these limits:

- It runs only when the kubeconfig context is `kind-kind-local` and the server URL of the context is on `127.0.0.1`.
- It creates `rtsec-lab` with the Pod Security level `baseline`, outside GitOps, and it deletes the namespace at the end.
- No step leaves `rtsec-lab`, needs a capability above the runtime default, touches a host path or connects to the internet.
- It writes the run ID in an annotation of `rtsec-lab` and in each command line.
- It collects the logs of the two tools one time, at least 35 seconds after the last step, with `--tail=-1`.

| Output | Content |
| --- | --- |
| `tmp/rtsec/<run-id>/tetragon.jsonl` | The Tetragon events of the run |
| `tmp/rtsec/<run-id>/falco.jsonl` | The Falco alerts of the run |
| `tmp/rtsec/<run-id>/summary.tsv` | One row for each step and tool: step, tool, fired (`yes` or `no`), rule or policy, time to event |

## Alerts

The alerts are JSON lines on the standard output of the containers. No alert backend receives them.

| Tool | Pod label | Container | Format |
| --- | --- | --- | --- |
| Tetragon agent | `app.kubernetes.io/name=tetragon` | `export-stdout` | One JSON event on each line: `process_exec`, `process_kprobe` and others |
| Tetragon operator | `app.kubernetes.io/name=tetragon-operator` | | No events |
| Falco | `app.kubernetes.io/name=falco` | `falco` | JSON alerts, mixed with plain log lines |

| Field | Values |
| --- | --- |
| Tetragon `process_kprobe.action` | `KPROBE_ACTION_POST`, `KPROBE_ACTION_SIGKILL`, `KPROBE_ACTION_OVERRIDE` |
| Tetragon `process.pod.namespace` | The namespace of the pod. `""` for a process that the agent cannot attribute to a pod. |
| Falco `output_fields["k8s.ns.name"]` | The namespace of the pod. `null` on the copy of the alert from the other node, and for a process outside Kubernetes. |
| Falco `output_fields["container.id"]` | The container ID. Equal on the two copies of an alert. |

On `kind-local`, both agents see each event of the lab. These rules apply:

- Tetragon: the agent of the other node emits the event with namespace `""`, about 30 seconds later. The entry `""` of `exportDenyList` drops it from the standard output. gRPC and `tetragon_events_total` keep it.
- Tetragon: an exec event can reach the standard output up to about 30 seconds after the step (event cache, `eventCacheRetries` 15 times 2 seconds).
- Falco: each alert occurs two times. A filter on `k8s.ns.name == "rtsec-lab"` keeps one copy. `container.id` is the key to remove duplicates.
- Under load, the kubelet rotates the log of `export-stdout`. `kubectl logs` then returns only the current file.

## Metrics

| Port | Tool | Metrics | Exposure |
| --- | --- | --- | --- |
| 2112 | Tetragon agent | `tetragon_events_exported_total`, `tetragon_events_total` | `ClusterIP`. With `hostNetwork: true`, also on the node IP, in the Docker network only. |
| 2113 | Tetragon operator | Operator metrics | `ClusterIP` |
| 8765 | Falco | `falcosecurity_scap_n_evts_total`, `falcosecurity_scap_n_drops_total` | `ClusterIP` |

The `security:measure` task reads the event volume from these metrics through a port-forward, not from the logs.

## Privileges and host paths

Both agents are DaemonSets on the host level. They read each process, file event and network event of the node. Tetragon can stop processes.

| Item | Tetragon | Falco |
| --- | --- | --- |
| Agent security context | `privileged: false`. Capabilities `SYS_ADMIN`, `SYS_PTRACE`, `SYS_RESOURCE`, `DAC_OVERRIDE` and `SYSLOG`. AppArmor `Unconfined`. | `privileged: false`. Capabilities `BPF`, `SYS_RESOURCE`, `PERFMON`, `SYS_PTRACE` and `SYS_ADMIN`. AppArmor `Unconfined`, from the chart annotation. |
| Privileged container | Init container `mount-bpf-fs` | None |
| Host namespaces | `hostNetwork: true`, `hostUsers: true` | None |
| Host paths | `/procHost` on `kind-local`: a read-only bind of the `/proc` of the Colima VM. Read-only stops only the writes to the procfs files: `/procHost/<pid>/root` reaches the file system of the VM. `/proc` on the other clusters. Also `/sys/fs/bpf`, `/var/run/cilium`, `/var/run/tetragon`, `/var/log/tetragon` | `/proc`, `/sys/kernel`, `/boot`, `/etc`, `/usr`, `/lib/modules`, the folders of the containerd socket |
| Socket | Unix gRPC socket on the host | containerd socket |

Tetragon pins its BPF maps below `/sys/fs/bpf/tetragon`. Cilium pins its maps below `/sys/fs/bpf/cilium` and `/sys/fs/bpf/tc`.

## RBAC

| Tool | Rules |
| --- | --- |
| Tetragon agent | `ClusterRole`: `get`, `list` and `watch` on `namespaces`, `nodes`, `pods`, `services`, the Tetragon kinds and the CRDs ([clusterrole.yaml](https://github.com/cilium/tetragon/blob/v1.8.0/install/kubernetes/tetragon/templates/clusterrole.yaml)) |
| Tetragon operator | Read on `pods`, write on `podinfo`, and `update`, `get`, `list` and `watch` on the three CRDs by `resourceNames`. No `create` on CRDs. |
| Falco | No `Role` and no `ClusterRole` |

No rendered role of the two components has a rule on `secrets`.

## Footprint

Each pod has a memory request equal to its limit, a CPU request and no CPU limit, as [Add a GitOps component](../how-to/add-a-gitops-component.md) requires.

| Pod (one on each node, except the operator) | CPU request | Memory request and limit |
| --- | --- | --- |
| Tetragon agent | `100m` | `768Mi` |
| Tetragon `export-stdout` | `10m` | `32Mi` |
| Tetragon operator (one pod) | `10m` | `128Mi` |
| Falco | `50m` | `256Mi` |

| Mode, on two nodes | CPU request | Memory request |
| --- | --- | --- |
| Tetragon | `230m` | `1728Mi` |
| Falco | `100m` | `512Mi` |
| Both | `330m` | `2240Mi` |

The values come from short measurements on `kind-local`, with one run for each mode. Each run has 3 minutes idle, then a load of 20 000 execs and one attack set. The numbers are indicative only. The drift of the VM memory is about ±50 MiB.

| Mode | Peak working set of one agent | Peak CPU of one agent |
| --- | --- | --- |
| Tetragon | 451 MiB | 65m |
| Falco | 55 MiB | 21m |

Kind nodes have no allocatable limit below the Colima VM. On `kind-local`, the requests are a reservation only, and the real use counts.

## Checks

| Rule | Check |
| --- | --- |
| No container, init container or ephemeral container has `securityContext.privileged: true`, except when each known namespace of the object, `metadata.namespace` and the component namespace, is in `pod_security_privileged` of `policy/data/labels.yaml` (`tetragon`, `falco`). An object with no known namespace fails. | Conftest (K16) |
| No `TracingPolicy` (`cilium.io`) has `Sigkill`, `Override`, `Signal`, `NotifyEnforcer` or `Set` in a `matchActions` or `matchReturnActions` array, and `spec.enforcers` is empty. | Conftest (K17) |
| Each lab pod is in its own file in `tests/runtime-security/`, and its image ends with a `sha256` digest. | Conftest |
| A `hostPath` volume on `/procHost`, on a path under it, or on a parent path is only in the namespace `tetragon`. No `hostPath` volume is on `/var/run/docker.sock` or `/run/docker.sock`. | Conftest (K18) |
| Each rendered CRD has the sync wave `-1`. | Conftest |
| Each rendered image has an explicit tag that is not `latest`. | Conftest |
| Each rendered Namespace is the namespace of its component in `cluster.yaml`. | Conftest (K15) |

The `lint:policy` inputs include `tests/runtime-security/`, so K17 and the digest rule also check the lab fixtures. The rules and their messages are in [Policies](policies.md) and [Labels and annotations](labels-and-annotations.md#checks).

## Related pages

- [Runtime security with Tetragon and Falco](../explanation/runtime-security-with-tetragon-and-falco.md)
- [Run the runtime security attack set](../how-to/run-the-runtime-security-attack-set.md)
- [Remove a runtime security tool](../how-to/remove-a-runtime-security-tool.md)
- [GitOps layout](gitops-layout.md): the files of a component, and the sync waves.
- [Mise tasks](mise-tasks.md): the `security:*` tasks.
- [Policies](policies.md): the Conftest rules.
- [cluster-kind](terraform-modules/cluster-kind/index.md): the mount of the host `/proc` at `/procHost`.
