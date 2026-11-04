# Run the runtime security attack set

This guide shows how to run the runtime security attack set on `kind-local`. It also shows how to read the alerts and measure the overhead of each tool.

Run the attack set when one of these occurs:

- A change to the `tetragon` or `falco` component needs a check of its detections.
- A demonstration needs the events of one tool, or of the two tools side by side.
- A comparison needs the overhead of one tool against the same base.

## Before you start

- `kind-local` runs, from `mise run instance:up kind-local`.
- The kubeconfig context is `kind-kind-local`.
- The computer has `kubectl` and `jq`. Refer to [Install the tools](install-the-tools.md).

## Enable the tools

1. Add the tools to the `infrastructure` list of `gitops/clusters/kind-local/cluster.yaml`:

   ```yaml
   infrastructure:
     - name: argocd
       namespace: argocd
     - name: tetragon
       namespace: tetragon
     - name: falco
       namespace: falco
   ```

   To run one tool only, add only its item.

2. To enable Tetragon on `kind-local`, add `gitops/clusters/kind-local/values/tetragon.yaml`:

   ```yaml
   tetragon:
     tetragon:
       hostProcPath: /procHost
   ```

   The other values are in [Tetragon values](../reference/runtime-security-components.md#tetragon-values).

3. Render the manifests:

   ```bash
   mise run manifests:render
   ```

4. Merge the change. The Applications sync `main`. Refer to [Make a change](make-a-change.md).
5. If the Applications do not sync in a few minutes, refer to [Force a sync](force-a-sync.md).
6. Make sure that each Application is `Synced` and `Healthy`. Name only the enabled tools:

   ```bash
   kubectl -n argocd get applications tetragon falco
   ```

7. Make sure that each DaemonSet has a ready pod on each node:

   ```bash
   kubectl -n tetragon get daemonset
   kubectl -n falco get daemonset
   ```

## Run the attack set

1. Run the task:

   ```bash
   mise run security:attack-set
   ```

2. Wait for the end of the task. It waits at least 35 seconds after the last step, then collects the logs.
3. Read the summary of the run:

   ```bash
   column -t -s $'\t' tmp/rtsec/<run-id>/summary.tsv
   ```

4. Look at the rows with `no` in the fired column. The steps and the fixtures are in [Attack set](../reference/runtime-security-components.md#attack-set).

The task prints the run ID. The events of the run are in `tmp/rtsec/<run-id>/tetragon.jsonl` and `tmp/rtsec/<run-id>/falco.jsonl`.

## Read the alerts

Read the alerts of the last 10 minutes from the agents. Keep `--tail=-1`: with `-l`, `kubectl logs` shows only the last 10 lines of each pod.

1. Read the Tetragon events:

   ```bash
   kubectl -n tetragon logs -l app.kubernetes.io/name=tetragon -c export-stdout --prefix --tail=-1 --since=10m \
     | sed 's/^\[[^]]*\] //' \
     | jq -c 'select(.process_kprobe or .process_exec) | {time, node: .node_name, policy: .process_kprobe.policy_name, action: .process_kprobe.action, ns: (.process_exec // .process_kprobe).process.pod.namespace, bin: (.process_exec // .process_kprobe).process.binary}'
   ```

2. Read the Falco alerts of `rtsec-lab`:

   ```bash
   kubectl -n falco logs -l app.kubernetes.io/name=falco -c falco --prefix --tail=-1 --since=10m \
     | sed 's/^\[[^]]*\] //' \
     | jq -R -c 'fromjson? | select(.rule and .output_fields["k8s.ns.name"] == "rtsec-lab") | {time, rule, priority, ns: .output_fields["k8s.ns.name"], proc: .output_fields["proc.name"], cid: .output_fields["container.id"]}'
   ```

   The namespace filter removes the copy of each alert from the other node, and the host noise.

3. If a Tetragon exec event is missing, wait 30 seconds and read the events again.

Do not read the alerts during a `security:measure` run. Its load rotates the log files, and `kubectl logs` then shows only the current file.

## Measure the overhead

1. Enable the tools of the mode, as in [Enable the tools](#enable-the-tools), up to the merge. For a mode with fewer tools, remove the other tools as in [Remove a runtime security tool](remove-a-runtime-security-tool.md).
2. Start from a new cluster:

   ```bash
   mise run instance:down kind-local
   mise run instance:up kind-local
   ```

3. Make sure that the Applications of the mode are `Synced` and `Healthy`.
4. Run the measurement with the same mode:

   ```bash
   mise run security:measure tetragon
   ```

   The argument is `tetragon`, `falco`, `both` or `none`. The task stops if the cluster does not agree with the argument.

5. Read the samples in `tmp/rtsec/measure-<mode>-<date>.tsv`.

For clean numbers, measure one tool at a time, and also measure `none` as the base. The `both` mode gives only the side-by-side events.

## Clean up after a run

1. If the task stopped before its end, delete the lab namespace:

   ```bash
   kubectl delete namespace rtsec-lab --ignore-not-found
   ```

2. To stop a tool, refer to [Remove a runtime security tool](remove-a-runtime-security-tool.md).

## Related pages

- [Runtime security components](../reference/runtime-security-components.md)
- [Mise tasks](../reference/mise-tasks.md)
- [Runtime security with Tetragon and Falco](../explanation/runtime-security-with-tetragon-and-falco.md)
