# How to Manage Secrets

Plain Kubernetes `Secret` objects must not be committed to Git because their `data` fields are only base64-encoded, not encrypted. This project uses [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to encrypt secrets with a cluster-specific key so they can be safely stored in the repository.

---

## Prerequisites

### Install kubeseal

`kubeseal` is the CLI tool that encrypts secrets using the cluster's public key.

```bash
# macOS
brew install kubeseal

# Linux (download the binary)
curl -L https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.30.0/kubeseal-0.30.0-linux-amd64.tar.gz \
  | tar -xz kubeseal
sudo mv kubeseal /usr/local/bin/
```

Verify `kubeseal` can reach the cluster:

```bash
kubeseal --fetch-cert
```

This should print a PEM certificate. If it fails, confirm your `kubectl` context points to the correct cluster.

---

## Create and Seal a Secret

### 1. Write the plain secret to a temporary file

Never commit this file. Write it to `/tmp/` or another location outside the repo:

```bash
kubectl create secret generic my-app-secret \
  --namespace my-app \
  --from-literal=API_KEY=supersecretvalue \
  --dry-run=client \
  -o yaml > /tmp/my-app-secret.yaml
```

### 2. Seal the secret

```bash
kubeseal \
  --namespace my-app \
  --format yaml \
  < /tmp/my-app-secret.yaml \
  > kubernetes/applications/my-app/sealed-secret.yaml
```

The output file contains a `SealedSecret` object. The `encryptedData` values are encrypted with the cluster's RSA public key and can only be decrypted by the Sealed Secrets controller running in the cluster.

### 3. Delete the plain secret file

```bash
rm /tmp/my-app-secret.yaml
```

---

## Add the Sealed Secret to a Deployment

Reference the unsealed secret (Sealed Secrets controller creates a matching `Secret`) in your `deployment.yaml`:

```yaml
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: my-app-secret      # matches metadata.name in the SealedSecret
        key: API_KEY
```

---

## Commit and Push

```bash
git add kubernetes/applications/my-app/sealed-secret.yaml
git commit -m "feat(my-app): add sealed API key secret"
git push
```

ArgoCD will apply the `SealedSecret` to the cluster. The Sealed Secrets controller decrypts it and creates a corresponding `Secret` object in the same namespace. The deployment then reads the secret as usual.

---

## Example: zigbee2mqtt

`kubernetes/applications/zigbee2mqtt/` includes a working example of a sealed secret. It stores the `ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD` environment variable:

```ascii
kubernetes/applications/zigbee2mqtt/
├── deployment.yaml        # references zigbee2mqtt-secrets
├── sealed-secret.yaml     # SealedSecret: zigbee2mqtt-secrets
└── ...
```

---

## Key Backup Warning

The Sealed Secrets encryption key is stored only in the cluster. If the cluster is destroyed without backing up the key, all sealed secrets become permanently unreadable. To back up the key:

```bash
kubectl get secret -n sealed-secrets \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-key-backup.yaml
```

Store this file securely outside the repository (e.g., a password manager).
