# Resize the Colima VM

Use this guide when `mise run instance:up kind-local` fails with `net/http: TLS handshake timeout`, or when the Kind control plane restarts again and again.

## Symptom

- The apply fails with `TLS handshake timeout` on many `kubectl_manifest` resources, for example in the `bootstrap-gateway-api` module.
- The pods `etcd` and `kube-controller-manager` restart. The liveness probes of etcd fail.
- The load average of the control plane node is high, and its free memory is almost zero.

## Cause

A TLS handshake timeout during the apply means that the VM is out of memory. The API server of the Kind cluster runs in the Docker VM. Colima starts a VM with 2 CPUs and 2 GiB of memory if you do not give a size. This size is too small for `kind-local`.

## Procedure

1. Check the memory of the VM:

   ```bash
   docker info --format '{{.MemTotal}}'
   colima list
   ```

   `instance:up` stops before the apply if the VM has less than 4 GiB of memory.

2. Resize the VM. The stop also stops the Kind cluster, so do this step when no work is running:

   ```bash
   colima stop && colima start --cpus 4 --memory 8
   ```

   Colima keeps the disk size. Do not use `--disk` to make the disk smaller. Colima cannot shrink a disk.

3. Run the task again:

   ```bash
   mise run instance:up kind-local
   ```

   Docker containers start again with the VM. If the cluster does not recover, run `mise run instance:down kind-local`, and then `instance:up`.

To make the task start Colima with another size, set `COLIMA_CPU`, `COLIMA_MEMORY` and `COLIMA_DISK`. Refer to [Mise tasks](../reference/mise-tasks.md).
