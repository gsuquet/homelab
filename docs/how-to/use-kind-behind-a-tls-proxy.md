# Use Kind behind a TLS-inspecting proxy

Some company networks have a proxy that decrypts TLS. The proxy signs each response with a company CA. macOS trusts this CA, but the Colima VM and the Kind nodes do not trust it. Thus image pulls fail with `x509: certificate signed by unknown authority`.

Do the steps in this guide only on a computer that is behind such a proxy. On other computers, `mise run instance:up kind-local` works with no change.

## Before you start

- You use Colima as the Docker runtime.
- The company CA is in the macOS System keychain. IT or an administrator installs it there.

## 1. Export the CA and make the Colima VM trust it

The `colima:trust-ca` task in the [dotfiles repository](https://github.com/gsuquet/dotfiles) does this step. It finds the CA, writes it to `~/.config/certs/proxy-ca.pem` and adds a provision script to the Colima profile:

```bash
mise run colima:trust-ca
colima restart
```

To do this step manually:

1. Find the name of the CA in Keychain Access, in the System keychain.
2. Export the CA to a file in your home folder. Colima mounts your home folder into the VM at the same path.

    ```bash
    mkdir -p ~/.config/certs
    security find-certificate -a -p -c "<CA name>" /Library/Keychains/System.keychain > ~/.config/certs/proxy-ca.pem
    ```

3. Run `colima start --edit` and add this entry. Use the absolute path, because the script runs as root.

    ```yaml
    provision:
      - mode: system
        script: |
          set -eu
          ca=/Users/<you>/.config/certs/proxy-ca.pem
          [ -s "$ca" ] || exit 0
          install -m 0644 "$ca" /usr/local/share/ca-certificates/proxy-ca.crt
          update-ca-certificates
          systemctl restart docker
    ```

To make sure that the VM trusts the CA, pull an image:

```bash
docker pull kindest/node:v1.36.1
```

## 2. Make the Kind nodes trust the CA

The `cluster-kind` module mounts each file in `extra_ca_certificate_paths` into the nodes. Create the file `instances/kind-local/local.auto.tfvars`. Git ignores this file.

```hcl
extra_ca_certificate_paths = ["~/.config/certs/proxy-ca.pem"]
```

The file must be in your home folder, because the Docker daemon in the Colima VM reads the path.

Then create the cluster:

```bash
mise run instance:up kind-local
```

If the cluster is already there, Terraform replaces it. Kind cannot add a mount to a node that runs.

## 3. Do a check of the result

```bash
docker exec kind-local-control-plane crictl pull quay.io/cilium/cilium:<version>
kubectl --kubeconfig ~/.kube/kind-kind-local get pods -A
```

All pods must be `Running`.

## Limits

The pods do not trust the CA. Only the node runtime trusts it. If an application in a pod calls an external HTTPS service through the proxy, that application must get the CA in a different way.
