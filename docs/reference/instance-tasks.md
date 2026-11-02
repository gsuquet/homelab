# Instance tasks

The instance tasks run Terraform on one instance, a folder in `instances/`. The scripts are in `.mise/tasks/instance/`. Their shared functions are in `.mise/tasks/_base/instance.sh`.

| Task | Script | Description |
| --- | --- | --- |
| `instance:plan` | `plan.sh` | Show the changes that `instance:up` would make to an instance. |
| `instance:up` | `up.sh` | Create or update an instance. |
| `instance:down` | `down.sh` | Destroy an instance. |

## Syntax

```bash
mise run instance:plan <instance>
mise run instance:up <instance>
mise run instance:down <instance>
```

| Argument | Required | Value |
| --- | --- | --- |
| `<instance>` | Yes | The instance name: the name of a folder in `instances/`, for example `kind-local`. |

The tasks have no flags.

## Steps

Each task does these steps in this order. A step that names `cluster-kind` occurs only when the `cluster` layer of `instance.yaml` lists the `cluster-kind` module.

| Step | `instance:plan` | `instance:up` | `instance:down` |
| --- | --- | --- | --- |
| 1. Validate `instances/<instance>/instance.yaml` against `schemas/instance.schema.json`. | Yes | Yes | Yes |
| 2. `cluster-kind`: check that the `kind` command exists. | No | Yes | No |
| 3. `cluster-kind`: check the size of a running Colima VM. Refer to [Colima size check](#colima-size-check). | Yes | Yes | No |
| 4. `cluster-kind`: make sure that Docker runs. Refer to [Docker runtime](#docker-runtime). | Yes | Yes | Yes |
| 5. `cluster-kind`: check the memory of the Docker VM. Refer to [Docker memory check](#docker-memory-check). | Yes | Yes | No |
| 6. Run `terraform init -input=false` in `instances/<instance>/`. | Yes | Yes | Yes |
| 7. `cluster-kind`: read the Terraform output `cluster_name`. | No | No | Yes |
| 8. Run Terraform. Refer to [Terraform commands](#terraform-commands). | `plan` | `apply`, two times | `destroy` |
| 9. `cluster-kind`: update the kubeconfig. Refer to [Kubeconfig](#kubeconfig). | No | Add the context | Remove the context |

`instance:down` does not check the size of the VM, so that a destroy works on a VM that is too small.

## Terraform commands

| Task | Commands |
| --- | --- |
| `instance:plan` | `terraform plan -input=false` |
| `instance:up` | `terraform apply -input=false <approve> -target=module.<block> ...`, then `terraform apply -input=false <approve>` |
| `instance:down` | `terraform destroy -input=false <approve>` |

All commands run with `-chdir=instances/<instance>`.

`instance:up` makes one `-target` flag for each `module` block in `instances/<instance>/*.tf` whose `source` is `../../modules/<module>`, where `<module>` is in the `cluster` layer of `instance.yaml`. For `kind-local`, the flag is `-target=module.kind_cluster`. If the `cluster` layer matches no `module` block, `instance:up` skips the first apply.

The providers of the other layers use the outputs of the cluster. `instance:plan` makes one full plan. When a change replaces the cluster, these outputs are unknown in that plan, and the plan can fail. `instance:up` does not have this problem, because it applies the cluster first.

`<approve>` depends on the `purpose` field of `instance.yaml`:

| `purpose` | `<approve>` | Effect |
| --- | --- | --- |
| `test`, `demo` | `-auto-approve` | Terraform applies or destroys with no question. |
| `production` | empty | Terraform asks for `yes` before each apply or destroy that has changes. |

`instance:plan` never asks for approval.

## Docker runtime

If `docker info` fails, the task starts a Docker runtime and waits for it. It runs `docker info` every 2 seconds, for a maximum of 120 seconds.

| `DOCKER_RUNTIME` | Command |
| --- | --- |
| `colima` | `colima start`, with the size in [Colima start size](#colima-start-size) |
| `orbstack` | `orb start` |
| `rancher-desktop` | `rdctl start` |
| `docker-desktop` | `open -a Docker` |
| not set | The first installed runtime, in the order of this table. The task starts Docker Desktop only on macOS, when `/Applications/Docker.app` exists. |

The task does not start a runtime when `DOCKER_NO_START=1`, or when it finds no installed runtime. It then stops with an error.

## Colima start size

When the task starts Colima, it runs `colima start --cpus <cpus> --memory <GiB>`, and adds `--disk <GiB>` when `COLIMA_DISK` has a value.

- `<cpus>` is `COLIMA_CPU`, default `4`.
- `<GiB>` is `COLIMA_MEMORY`, default `8`.
- The task keeps 4 GiB of memory for the host. If the host memory minus 4 GiB is less than the memory value, the memory becomes that difference. The task prints a warning. The rule does not apply when the difference is less than 1 GiB. This rule also applies to a value from `COLIMA_MEMORY`.
- If `COLIMA_CPU` or `COLIMA_MEMORY` is not set and the saved Colima VM is larger, the task uses the saved value. The task never makes a saved VM smaller unless a variable sets the value.

The saved size is the size of the `default` profile in `colima list --json`. If that command gives no result, the task reads `colima.yaml` of the `default` profile in `$COLIMA_HOME` (default `~/.colima`), then in `$XDG_CONFIG_HOME/colima` (default `~/.config/colima`).

## Colima size check

This check runs only when Colima is the active runtime: `DOCKER_RUNTIME=colima`, or `DOCKER_RUNTIME` is not set and the Docker context is `colima` or `colima-<profile>`. It reads the `default` profile from `colima list --json`, only when its status is `Running`.

If the VM has fewer CPUs or less memory than the [Colima start size](#colima-start-size), the task prints two warnings. The second one contains the resize command:

```text
colima stop && colima start --cpus <cpus> --memory <GiB>
```

The task never restarts Colima, because a restart stops the running cluster. The task continues, unless `COLIMA_STRICT=1`.

## Docker memory check

The task reads `docker info --format '{{.MemTotal}}'`. If the value is less than 90% of `KIND_MIN_MEMORY`, the task stops with an error. The error contains the Colima resize command when Colima is the active runtime. If the task cannot read the value, it prints a warning and skips the check.

Below this minimum, the Kind control plane runs out of memory, and the apply fails with `TLS handshake timeout`. Refer to [Resize the Colima VM](../how-to/resize-the-colima-vm.md).

## Kubeconfig

For a `cluster-kind` instance:

- The `cluster-kind` module writes the kubeconfig of the cluster to `~/.kube/kind-<cluster>`.
- After the apply, `instance:up` runs `kind export kubeconfig --name <cluster>`. kind adds the cluster, the user and the context `kind-<cluster>` to `~/.kube/config`, or to the first file in `KUBECONFIG` that exists. The context `kind-<cluster>` becomes the current context. kind changes no other entry.
- After the destroy, `instance:down` removes the context, the cluster and the user `kind-<cluster>` with `kubectl config`. It removes only the entries that exist. If `kind-<cluster>` was the current context, no context is current after the task. If `kubectl` is missing, the task prints a warning and removes nothing.

`<cluster>` is the value of the Terraform output `cluster_name`. Each instance that uses `cluster-kind` must have this output. `mise run schemas:check` fails without it.

## Environment variables

The tasks read these variables only for an instance that uses `cluster-kind`.

| Variable | Default | Used by | Meaning |
| --- | --- | --- | --- |
| `DOCKER_RUNTIME` | not set | all | The runtime to start: `colima`, `orbstack`, `rancher-desktop` or `docker-desktop`. Another value stops the task with an error. |
| `DOCKER_NO_START` | `0` | all | `1`: do not start a runtime. If Docker does not run, the task stops with an error. |
| `COLIMA_CPU` | `4` | all | CPUs of the Colima VM. A whole number greater than 0. |
| `COLIMA_MEMORY` | `8` | all | Memory of the Colima VM, in GiB. A whole number greater than 0. |
| `COLIMA_DISK` | not set | all | Disk of the Colima VM, in GiB. A whole number greater than 0. When not set, Colima keeps its disk size. Colima cannot make a disk smaller. |
| `COLIMA_STRICT` | `0` | `instance:plan`, `instance:up` | `1`: stop with an error, instead of a warning, when the running Colima VM is too small. |
| `KIND_MIN_MEMORY` | `4` | `instance:plan`, `instance:up` | Minimum memory of the Docker VM, in GiB. A whole number greater than 0. |
| `KUBECONFIG` | not set | `instance:up`, `instance:down` | The kubeconfig files that `kind` and `kubectl` change. |
| `DEBUG` | not set | `instance:plan`, `instance:up` | When set, the Colima size check prints a message if it cannot read the size of the VM. |

The task validates `COLIMA_CPU`, `COLIMA_MEMORY` and `COLIMA_DISK` only when it starts Colima, checks its size, or prints the resize command.

## Exit status

The scripts run with `set -euo pipefail`. A task exits with `0` after its last message:

| Task | Last message |
| --- | --- |
| `instance:plan` | `[INFO] ✓ Plan complete: <instance>` |
| `instance:up` | `[INFO] ✓ Instance is up: <instance>` |
| `instance:down` | `[INFO] ✓ Instance is down: <instance>` |

A task exits with `1` after one of these errors:

| Error | Task |
| --- | --- |
| `No instance '<instance>': <file> does not exist.` | all |
| `<file> does not comply with schemas/instance.schema.json.` | all |
| `The kind command is missing. Run 'mise install' in the repository.` | `instance:up` |
| `The docker command is missing. Kind needs it. ...` | all |
| `DOCKER_RUNTIME='<value>' is not valid. ...` | all |
| `Docker is not running. Kind needs it. Start Docker and try again.` | all |
| `Docker did not start in 120 seconds.` | all |
| `<variable>='<value>' is not valid. Use a whole number greater than 0.` | all |
| `KIND_MIN_MEMORY='<value>' is not valid. ...` | `instance:plan`, `instance:up` |
| `The Docker VM has <n> MiB of memory. A Kind cluster needs at least <n> GiB (KIND_MIN_MEMORY), ...` | `instance:plan`, `instance:up` |
| `COLIMA_STRICT=1: stopping because the Colima VM is too small.` | `instance:plan`, `instance:up` |

When another command fails, for example `terraform`, the task stops at once with the exit status of that command. In `instance:down`, a failure to read `cluster_name` does not stop the task.

## Related pages

- [Mise tasks](mise-tasks.md): all the other tasks.
- [Schemas](schemas.md): the fields of `instance.yaml`.
- [Run your first local cluster](../tutorials/run-your-first-local-cluster.md)
- [Use Kind behind a TLS-inspecting proxy](../how-to/use-kind-behind-a-tls-proxy.md)
