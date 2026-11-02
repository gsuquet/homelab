# Resize the Colima VM

This guide shows how to give the Colima VM more CPUs or memory for a Kind instance.

Resize the VM when one of these occurs:

- `mise run instance:up kind-local` fails with `net/http: TLS handshake timeout`, often on `kubectl_manifest` resources.
- `instance:up` stops with `The Docker VM has <n> MiB of memory. A Kind cluster needs at least 4 GiB`.
- `instance:up` or `instance:plan` prints the warning `The Colima VM has <n> CPUs and <n> GiB of memory`.
- The `etcd` and `kube-controller-manager` pods of the control plane restart again and again.

## Resize the VM

1. Check the size of the VM:

   ```bash
   colima list
   docker info --format '{{.MemTotal}}'
   ```

2. Stop all work on the cluster. The stop of Colima also stops the Kind nodes.
3. Restart Colima with the new size:

   ```bash
   colima stop && colima start --cpus 4 --memory 8
   ```

   If the task printed a warning, use the command in the warning. It contains the size that the task asks for.

4. Run the task again:

   ```bash
   mise run instance:up kind-local
   ```

5. If the cluster does not recover, recreate it:

   ```bash
   mise run instance:down kind-local
   mise run instance:up kind-local
   ```

Do not use `--disk` to make the disk smaller. Colima cannot shrink a disk.

## Let the task set the size

If Colima does not run, `instance:up` starts it. To start it with a different size, set the size in the environment:

```bash
colima stop
COLIMA_CPU=6 COLIMA_MEMORY=12 mise run instance:up kind-local
```

To make the task fail, instead of only warn, when the running VM is too small, set `COLIMA_STRICT=1`.

For the defaults and the limits of these variables, refer to [Instance tasks](../reference/instance-tasks.md#environment-variables).
